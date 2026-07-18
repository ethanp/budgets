class MonthSummary {
  const MonthSummary({
    required this.yearMonth,
    required this.outflowCents,
    required this.inflowCents,
    required this.accountSpend,
    this.lastSyncedAt,
  });

  final String yearMonth;
  final int outflowCents;
  final int inflowCents;
  final List<AccountSpendRow> accountSpend;
  final DateTime? lastSyncedAt;

  int get netCents => inflowCents + outflowCents;
}

class AccountSpendRow {
  const AccountSpendRow({
    required this.accountId,
    required this.accountName,
    required this.spentCents,
  });

  final String accountId;
  final String accountName;
  final int spentCents;
}

class CategoryMonthRow {
  const CategoryMonthRow({
    required this.categoryId,
    required this.categoryName,
    required this.budgetCents,
    required this.spentCents,
  });

  final String categoryId;
  final String categoryName;
  final int budgetCents;
  final int spentCents;

  int get remainingCents => budgetCents - spentCents;
  double get progress {
    if (budgetCents <= 0) return spentCents > 0 ? 1 : 0;
    return (spentCents / budgetCents).clamp(0, 2);
  }
}
