import 'package:budgets/domain/category.dart';
import 'package:budgets/data/sqlite/budgets_database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

class CategoriesRepository {
  CategoriesRepository(this._budgetsDatabase);

  final BudgetsDatabase _budgetsDatabase;
  final _uuid = const Uuid();

  Database get _database => _budgetsDatabase.database;

  List<SpendCategory> listActive() {
    return _database
        .select(
          '''
          SELECT * FROM categories
          WHERE archived = 0
          ORDER BY sort_order ASC, name COLLATE NOCASE
          ''',
        )
        .map(_categoryFromRow)
        .toList();
  }

  List<SpendCategory> listAll() {
    return _database
        .select('SELECT * FROM categories ORDER BY sort_order ASC')
        .map(_categoryFromRow)
        .toList();
  }

  void upsertCategory(SpendCategory category) {
    _database.execute(
      '''
      INSERT INTO categories (id, name, sort_order, archived, color_token)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        sort_order = excluded.sort_order,
        archived = excluded.archived,
        color_token = excluded.color_token
      ''',
      [
        category.id,
        category.name,
        category.sortOrder,
        category.archived ? 1 : 0,
        category.colorToken,
      ],
    );
  }

  CategoryBudget? budgetFor({
    required String categoryId,
    required String yearMonth,
  }) {
    final rows = _database.select(
      '''
      SELECT * FROM category_budgets
      WHERE category_id = ? AND year_month = ?
      LIMIT 1
      ''',
      [categoryId, yearMonth],
    );
    if (rows.isEmpty) return null;
    return _budgetFromRow(rows.first);
  }

  List<CategoryBudget> budgetsForMonth(String yearMonth) {
    return _database
        .select(
          'SELECT * FROM category_budgets WHERE year_month = ?',
          [yearMonth],
        )
        .map(_budgetFromRow)
        .toList();
  }

  void setBudget({
    required String categoryId,
    required String yearMonth,
    required int amountCents,
  }) {
    final existing = budgetFor(categoryId: categoryId, yearMonth: yearMonth);
    final id = existing?.id ?? _uuid.v4();
    _database.execute(
      '''
      INSERT INTO category_budgets (id, category_id, year_month, amount_cents)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(category_id, year_month) DO UPDATE SET
        amount_cents = excluded.amount_cents
      ''',
      [id, categoryId, yearMonth, amountCents],
    );
  }

  List<CategorizationRule> listRules() {
    return _database
        .select(
          'SELECT * FROM categorization_rules ORDER BY priority DESC, pattern',
        )
        .map(_ruleFromRow)
        .toList();
  }

  void upsertRule(CategorizationRule rule) {
    _database.execute(
      '''
      INSERT INTO categorization_rules
        (id, match_type, pattern, category_id, priority)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        match_type = excluded.match_type,
        pattern = excluded.pattern,
        category_id = excluded.category_id,
        priority = excluded.priority
      ''',
      [
        rule.id,
        rule.matchType.storageValue,
        rule.pattern,
        rule.categoryId,
        rule.priority,
      ],
    );
  }

  void deleteRule(String ruleId) {
    _database.execute(
      'DELETE FROM categorization_rules WHERE id = ?',
      [ruleId],
    );
  }

  static SpendCategory _categoryFromRow(Row row) {
    return SpendCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      sortOrder: row['sort_order'] as int,
      archived: (row['archived'] as int) == 1,
      colorToken: row['color_token'] as String?,
    );
  }

  static CategoryBudget _budgetFromRow(Row row) {
    return CategoryBudget(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      yearMonth: row['year_month'] as String,
      amountCents: row['amount_cents'] as int,
    );
  }

  static CategorizationRule _ruleFromRow(Row row) {
    return CategorizationRule(
      id: row['id'] as String,
      matchType: RuleMatchType.fromStorage(row['match_type'] as String),
      pattern: row['pattern'] as String,
      categoryId: row['category_id'] as String,
      priority: row['priority'] as int,
    );
  }
}
