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

  /// Outflow is a positive spend total, so net is income minus spent.
  int get netCents => inflowCents - outflowCents;
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
    required this.annualizedSpendCents,
    required this.spentCents,
  });

  final String categoryId;
  final String categoryName;

  /// Trailing-year outflow, scaled up if fewer than 365 observed days.
  final int annualizedSpendCents;

  /// Calendar-month outflow for the selected year-month.
  final int spentCents;
}
