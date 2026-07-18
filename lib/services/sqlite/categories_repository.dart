import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

class CategoriesRepository {
  CategoriesRepository(this._powerSync);

  final PowerSyncDatabase _powerSync;
  final _uuid = const Uuid();

  Future<List<SpendCategory>> listActive() async {
    final rows = await _powerSync.getAll(
      '''
      SELECT * FROM categories
      WHERE archived = 0
      ORDER BY sort_order ASC, name COLLATE NOCASE
      ''',
    );
    return rows.map(_categoryFromRow).toList();
  }

  Future<List<SpendCategory>> listAll() async {
    final rows = await _powerSync.getAll(
      'SELECT * FROM categories ORDER BY sort_order ASC',
    );
    return rows.map(_categoryFromRow).toList();
  }

  Future<void> upsertCategory(SpendCategory category) async {
    await _powerSync.upsert('categories', {
      'id': category.id,
      'name': category.name,
      'sort_order': category.sortOrder,
      'archived': category.archived ? 1 : 0,
      'color_token': category.colorToken,
    });
  }

  Future<SpendCategory> createCategory({required String name}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name is required.');
    }
    if (SpecialCategory.isReservedName(trimmedName)) {
      throw ArgumentError(
        '"$trimmedName" is a built-in category and cannot be recreated.',
      );
    }
    final active = await listActive();
    var nextSortOrder = 0;
    for (final category in active) {
      if (category.sortOrder >= nextSortOrder) {
        nextSortOrder = category.sortOrder + 1;
      }
    }
    final category = SpendCategory(
      id: _uuid.v4(),
      name: trimmedName,
      sortOrder: nextSortOrder,
      archived: false,
    );
    await upsertCategory(category);
    return category;
  }

  Future<void> renameCategory({
    required String categoryId,
    required String name,
  }) async {
    if (SpecialCategory.isSpecialId(categoryId)) {
      throw StateError('Built-in categories cannot be renamed.');
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name is required.');
    }
    if (SpecialCategory.isReservedName(trimmedName)) {
      throw ArgumentError(
        '"$trimmedName" is reserved for a built-in category.',
      );
    }
    final row = await _powerSync.getOptional(
      'SELECT * FROM categories WHERE id = ? LIMIT 1',
      [categoryId],
    );
    if (row == null) {
      throw StateError('Category not found.');
    }
    final existing = _categoryFromRow(row);
    await upsertCategory(
      SpendCategory(
        id: existing.id,
        name: trimmedName,
        sortOrder: existing.sortOrder,
        archived: existing.archived,
        colorToken: existing.colorToken,
      ),
    );
  }

  /// Move all spend/rules from [fromCategoryId] into [intoCategoryId],
  /// then hard-delete the source category. Use when retiring a duplicate
  /// (e.g. "Dining" → "Restaurants").
  Future<void> mergeCategoryInto({
    required String fromCategoryId,
    required String intoCategoryId,
  }) async {
    if (fromCategoryId == intoCategoryId) {
      throw ArgumentError('Cannot merge a category into itself.');
    }
    if (SpecialCategory.isSpecialId(fromCategoryId)) {
      throw StateError('Built-in categories cannot be merged away.');
    }
    await _ensureCategoriesExist(fromCategoryId, intoCategoryId);
    await _moveTransactionsAndRules(
      fromCategoryId: fromCategoryId,
      intoCategoryId: intoCategoryId,
    );
    await _powerSync.execute(
      'DELETE FROM categories WHERE id = ?',
      [fromCategoryId],
    );
  }

  Future<void> _ensureCategoriesExist(
    String fromCategoryId,
    String intoCategoryId,
  ) async {
    final fromRow = await _powerSync.getOptional(
      'SELECT id FROM categories WHERE id = ? LIMIT 1',
      [fromCategoryId],
    );
    final intoRow = await _powerSync.getOptional(
      'SELECT id FROM categories WHERE id = ? LIMIT 1',
      [intoCategoryId],
    );
    if (fromRow == null || intoRow == null) {
      throw StateError('Both categories must exist to merge.');
    }
  }

  Future<void> _moveTransactionsAndRules({
    required String fromCategoryId,
    required String intoCategoryId,
  }) async {
    await _powerSync.execute(
      'UPDATE transactions SET user_category_id = ? WHERE user_category_id = ?',
      [intoCategoryId, fromCategoryId],
    );
    await _powerSync.execute(
      '''
      UPDATE transactions
      SET suggested_category_id = ?
      WHERE suggested_category_id = ?
      ''',
      [intoCategoryId, fromCategoryId],
    );
    await _powerSync.execute(
      'UPDATE categorization_rules SET category_id = ? WHERE category_id = ?',
      [intoCategoryId, fromCategoryId],
    );
  }

  Future<List<CategorizationRule>> listRules() async {
    final rows = await _powerSync.getAll(
      'SELECT * FROM categorization_rules ORDER BY priority DESC, pattern',
    );
    return rows.map(_ruleFromRow).toList();
  }

  Future<void> upsertRule(CategorizationRule rule) async {
    await _powerSync.upsert('categorization_rules', {
      'id': rule.id,
      'match_type': rule.matchType.storageValue,
      'pattern': rule.pattern,
      'category_id': rule.categoryId,
      'priority': rule.priority,
    });
  }

  Future<void> deleteRule(String ruleId) async {
    await _powerSync.execute(
      'DELETE FROM categorization_rules WHERE id = ?',
      [ruleId],
    );
  }

  static SpendCategory _categoryFromRow(dynamic row) {
    return SpendCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      sortOrder: _asInt(row['sort_order']),
      archived: _asInt(row['archived']) == 1,
      colorToken: row['color_token'] as String?,
    );
  }

  static CategorizationRule _ruleFromRow(dynamic row) {
    return CategorizationRule(
      id: row['id'] as String,
      matchType: RuleMatchType.fromStorage(row['match_type'] as String),
      pattern: row['pattern'] as String,
      categoryId: row['category_id'] as String,
      priority: _asInt(row['priority']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse('$value');
  }
}
