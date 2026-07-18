import 'package:budgets/domain/category.dart';
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

  Future<CategoryBudget?> budgetFor({
    required String categoryId,
    required String yearMonth,
  }) async {
    final row = await _powerSync.getOptional(
      '''
      SELECT * FROM category_budgets
      WHERE category_id = ? AND year_month = ?
      LIMIT 1
      ''',
      [categoryId, yearMonth],
    );
    if (row == null) return null;
    return _budgetFromRow(row);
  }

  Future<List<CategoryBudget>> budgetsForMonth(String yearMonth) async {
    final rows = await _powerSync.getAll(
      'SELECT * FROM category_budgets WHERE year_month = ?',
      [yearMonth],
    );
    return rows.map(_budgetFromRow).toList();
  }

  Future<void> setBudget({
    required String categoryId,
    required String yearMonth,
    required int amountCents,
  }) async {
    final existing = await budgetFor(
      categoryId: categoryId,
      yearMonth: yearMonth,
    );
    final id = existing?.id ?? _uuid.v4();
    await _powerSync.upsert('category_budgets', {
      'id': id,
      'category_id': categoryId,
      'year_month': yearMonth,
      'amount_cents': amountCents,
    });
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

  static CategoryBudget _budgetFromRow(dynamic row) {
    return CategoryBudget(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      yearMonth: row['year_month'] as String,
      amountCents: _asInt(row['amount_cents']),
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
