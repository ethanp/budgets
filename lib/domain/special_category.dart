import 'package:spend_trends/domain/category.dart';

/// Built-in categories with stable ids.
///
/// [income] / [transfer] are cash-flow (excluded from spend totals).
/// [housing] is a built-in spend category (kept in spend Trends / month rows)
/// so its color and future housing-specific behavior stay consistent.
enum SpecialCategory({
  required final String id,
  required final String name,
  required final int sortOrder,
}) {
  housing(id: 'cat_housing', name: 'Housing', sortOrder: 3),
  income(id: 'cat_income', name: 'Income', sortOrder: 1000),
  transfer(id: 'cat_transfer', name: 'Transfer', sortOrder: 1001);

  static final ids = {for (final special in values) special.id};

  /// Income + Transfer only — excluded from spend series and month rows.
  static final flowIds = {income.id, transfer.id};

  static final _idsByNormalizedName = {
    for (final special in values)
      CategoryName(special.name).normalized: special.id,
  };

  static final housingName = CategoryName(housing.name);

  static bool isSpecialId(String? categoryId) =>
      categoryId != null && ids.contains(categoryId);

  static bool isFlowId(String? categoryId) =>
      categoryId != null && flowIds.contains(categoryId);

  static bool isHousingId(String? categoryId) => categoryId == housing.id;

  static bool isHousingName(String? name) =>
      name != null && CategoryName(name).matches(housingName);

  static bool isIncomeId(String? categoryId) => categoryId == income.id;

  static bool isTransferId(String? categoryId) => categoryId == transfer.id;

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

extension SpendCategorySpecial on SpendCategory {
  bool get isHousing =>
      SpecialCategory.isHousingId(id) || SpecialCategory.isHousingName(name);

  bool get isFlow => SpecialCategory.isFlowId(id);

  bool get isIncome => SpecialCategory.isIncomeId(id);

  bool get isTransfer => SpecialCategory.isTransferId(id);

  /// Built-in catch bucket (`cat_other` or display name "Other").
  bool get isOther =>
      id == 'cat_other' || CategoryName(name).normalized == 'other';

  /// Broad catch-all names the LLM must not treat as real categories.
  bool get isCatchAll => id == 'cat_other' || CategoryName(name).isCatchAll;
}

extension CategoryNameCatchAll on CategoryName {
  bool get isCatchAll {
    return normalized == 'other' ||
        normalized == 'misc' ||
        normalized == 'miscellaneous' ||
        normalized == 'uncategorized' ||
        normalized == 'general';
  }
}
