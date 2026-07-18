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
    required this.avg30DaySpendCents,
    required this.spentCents,
  });

  final String categoryId;
  final String categoryName;

  /// Total outflow in the rolling last 30 days.
  final int avg30DaySpendCents;

  /// Calendar-month outflow for the selected year-month.
  final int spentCents;

  /// Positive when month spend is under the 30-day total; negative when over.
  int get vsAvgCents => avg30DaySpendCents - spentCents;

  double get progress {
    if (avg30DaySpendCents <= 0) return spentCents > 0 ? 1 : 0;
    return (spentCents / avg30DaySpendCents).clamp(0, 2);
  }
}
