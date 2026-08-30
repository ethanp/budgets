class const MonthSummary({
  required final String yearMonth,
  required final int outflowCents,
  required final int inflowCents,
  required final List<AccountSpendRow> accountSpend,
  final DateTime? lastSyncedAt,
}) {
  /// Outflow is a positive spend total, so net is income minus spent.
  int get netCents => inflowCents - outflowCents;
}

class const AccountSpendRow({
  required final String accountId,
  required final String accountName,
  required final int spentCents,
});

class const CategoryMonthRow({
  required final String categoryId,
  required final String categoryName,

  /// Trailing-year outflow, scaled up if fewer than 365 observed days.
  required final int annualizedSpendCents,

  /// Calendar-month outflow for the selected year-month.
  required final int spentCents,
});
