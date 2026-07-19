import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
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

  Future<List<CategoryGroup>> listGroups() async {
    final rows = await _powerSync.getAll(
      '''
      SELECT * FROM category_groups
      ORDER BY sort_order ASC, name COLLATE NOCASE
      ''',
    );
    return rows.map(_groupFromRow).toList();
  }

  Future<void> upsertCategory(SpendCategory category) async {
    await _powerSync.upsert('categories', {
      'id': category.id,
      'name': category.name,
      'sort_order': category.sortOrder,
      'archived': category.archived ? 1 : 0,
      'color_token': category.colorToken,
      'group_id': category.groupId,
    });
  }

  Future<void> upsertGroup(CategoryGroup group) async {
    await _powerSync.upsert('category_groups', {
      'id': group.id,
      'name': group.name,
      'sort_order': group.sortOrder,
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

  Future<CategoryGroup> createGroup({required String name}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name is required.');
    }
    final groups = await listGroups();
    var nextSortOrder = 0;
    for (final group in groups) {
      if (group.sortOrder >= nextSortOrder) {
        nextSortOrder = group.sortOrder + 1;
      }
    }
    final group = CategoryGroup(
      id: _uuid.v4(),
      name: trimmedName,
      sortOrder: nextSortOrder,
    );
    await upsertGroup(group);
    return group;
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
    final existing = await _requireCategory(categoryId);
    await upsertCategory(existing.copyWith(name: trimmedName));
  }

  Future<void> renameGroup({
    required String groupId,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name is required.');
    }
    final existing = await _requireGroup(groupId);
    await upsertGroup(
      CategoryGroup(
        id: existing.id,
        name: trimmedName,
        sortOrder: existing.sortOrder,
      ),
    );
  }

  Future<void> setCategoryGroup({
    required String categoryId,
    String? groupId,
  }) async {
    if (SpecialCategory.isSpecialId(categoryId)) {
      throw StateError('Built-in categories cannot join a group.');
    }
    if (groupId != null) {
      await _requireGroup(groupId);
    }
    final existing = await _requireCategory(categoryId);
    await upsertCategory(
      existing.copyWith(
        groupId: groupId,
        clearGroupId: groupId == null,
      ),
    );
  }

  /// Deletes the group and clears membership on its categories.
  Future<void> deleteGroup(String groupId) async {
    await _requireGroup(groupId);
    await _powerSync.execute(
      'UPDATE categories SET group_id = NULL WHERE group_id = ?',
      [groupId],
    );
    await _powerSync.execute(
      'DELETE FROM category_groups WHERE id = ?',
      [groupId],
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

  /// Ensures a lowest-priority contains rule for import defaults.
  ///
  /// Does not overwrite a stronger (higher-priority) rule for the same pattern.
  Future<void> ensureDefaultImportContainsRule({
    required String pattern,
    required String categoryId,
  }) async {
    final normalizedPattern = pattern.trim().toLowerCase();
    if (normalizedPattern.isEmpty) return;

    final rules = await listRules();
    for (final rule in rules) {
      if (rule.matchType != RuleMatchType.merchantContains) continue;
      if (rule.pattern.trim().toLowerCase() != normalizedPattern) continue;
      if (rule.priority > CategorizationRule.defaultImportPriority) return;
      if (rule.categoryId == categoryId) return;
      await upsertRule(
        CategorizationRule(
          id: rule.id,
          matchType: RuleMatchType.merchantContains,
          pattern: normalizedPattern,
          categoryId: categoryId,
          priority: CategorizationRule.defaultImportPriority,
        ),
      );
      return;
    }

    await upsertRule(
      CategorizationRule(
        id: _uuid.v4(),
        matchType: RuleMatchType.merchantContains,
        pattern: normalizedPattern,
        categoryId: categoryId,
        priority: CategorizationRule.defaultImportPriority,
      ),
    );
  }

  Future<void> deleteRule(String ruleId) async {
    await _powerSync.execute(
      'DELETE FROM categorization_rules WHERE id = ?',
      [ruleId],
    );
  }

  Future<SpendCategory> _requireCategory(String categoryId) async {
    final row = await _powerSync.getOptional(
      'SELECT * FROM categories WHERE id = ? LIMIT 1',
      [categoryId],
    );
    if (row == null) {
      throw StateError('Category not found.');
    }
    return _categoryFromRow(row);
  }

  Future<CategoryGroup> _requireGroup(String groupId) async {
    final row = await _powerSync.getOptional(
      'SELECT * FROM category_groups WHERE id = ? LIMIT 1',
      [groupId],
    );
    if (row == null) {
      throw StateError('Group not found.');
    }
    return _groupFromRow(row);
  }

  static SpendCategory _categoryFromRow(dynamic row) {
    return SpendCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      sortOrder: _asInt(row['sort_order']),
      archived: _asInt(row['archived']) == 1,
      colorToken: row['color_token'] as String?,
      groupId: row['group_id'] as String?,
    );
  }

  static CategoryGroup _groupFromRow(dynamic row) {
    return CategoryGroup(
      id: row['id'] as String,
      name: row['name'] as String,
      sortOrder: _asInt(row['sort_order']),
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
