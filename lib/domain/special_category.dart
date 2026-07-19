import 'package:budgets/domain/category.dart';

/// Built-in categories with stable ids.
///
/// [income] / [transfer] are cash-flow (excluded from spend totals).
/// [housing] is a built-in spend category (kept in spend Trends / month rows)
/// so its color and future housing-specific behavior stay consistent.
enum SpecialCategory {
  housing(
    id: 'cat_housing',
    name: 'Housing',
    sortOrder: 3,
  ),
  income(
    id: 'cat_income',
    name: 'Income',
    sortOrder: 1000,
  ),
  transfer(
    id: 'cat_transfer',
    name: 'Transfer',
    sortOrder: 1001,
  );

  const SpecialCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;

  static final ids = {for (final special in values) special.id};

  /// Income + Transfer only — excluded from spend series and month rows.
  static final flowIds = {income.id, transfer.id};

  static final _idsByNormalizedName = {
    for (final special in values) CategoryName(special.name).normalized: special.id,
  };

  static final housingName = CategoryName(housing.name);

  static bool isSpecialId(String? categoryId) =>
      categoryId != null && ids.contains(categoryId);

  static bool isFlowId(String? categoryId) =>
      categoryId != null && flowIds.contains(categoryId);

  static bool isHousingId(String? categoryId) => categoryId == housing.id;

  static bool isHousingName(String? name) =>
      name != null && CategoryName(name).matches(housingName);

  /// Id match, or reserved name (covers pre-merge rows still named Housing).
  static bool isHousingCategory(SpendCategory category) =>
      isHousingId(category.id) || isHousingName(category.name);

  static bool isIncomeId(String? categoryId) => categoryId == income.id;

  static bool isTransferId(String? categoryId) => categoryId == transfer.id;

  static bool isFlowCategory(SpendCategory category) => isFlowId(category.id);

  static bool isReservedName(String name) =>
      _idsByNormalizedName.containsKey(CategoryName(name).normalized);

  /// Maps Copilot / legacy `transaction_type` values onto a cash-flow category.
  static SpecialCategory? fromTransactionType(String? transactionType) {
    final type = transactionType?.trim().toLowerCase() ?? '';
    if (type == 'income') return income;
    if (type == 'transfer' || type == 'internal transfer') return transfer;
    return null;
  }

  SpendCategory asSpendCategory({bool archived = false}) => SpendCategory(
        id: id,
        name: name,
        sortOrder: sortOrder,
        archived: archived,
      );
}
