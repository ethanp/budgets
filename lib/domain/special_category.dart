import 'package:budgets/domain/category.dart';

/// Built-in cash-flow categories. Identity is the fixed id — not transaction type.
enum SpecialCategory {
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

  static final ids = {income.id, transfer.id};

  static final _idsByLowerName = {
    for (final special in values) special.name.toLowerCase(): special.id,
  };

  static bool isSpecialId(String? categoryId) =>
      categoryId != null && ids.contains(categoryId);

  static bool isIncomeId(String? categoryId) => categoryId == income.id;

  static bool isTransferId(String? categoryId) => categoryId == transfer.id;

  static bool isFlowCategory(SpendCategory category) => isSpecialId(category.id);

  static bool isReservedName(String name) =>
      _idsByLowerName.containsKey(name.trim().toLowerCase());

  /// Maps Copilot / legacy `transaction_type` values onto a special category.
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
