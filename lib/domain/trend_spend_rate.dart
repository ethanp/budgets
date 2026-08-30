/// Whether a Trends chart plots annualized pace or absolute dollar levels.
enum TrendValueKind() {
  /// Centered-year spend / cash-flow pace (yr/mo/day toggle applies).
  pace,

  /// Point-in-time dollars (e.g. net worth); no rate scaling.
  level,
}

/// Display rate for Trends legend / inspect amounts (chart series stay annualized).
enum TrendSpendRate({
  required final String shortLabel,
  required final String toggleLabel,

  /// Divide centered-year annualized cents by this to get the display rate.
  required final int annualDivisor,
}) {
  perYear(shortLabel: '/ yr', toggleLabel: 'yr', annualDivisor: 1),
  perMonth(shortLabel: '/ mo', toggleLabel: 'mo', annualDivisor: 12),
  perDay(shortLabel: '/ day', toggleLabel: 'day', annualDivisor: 365);

  /// Convert centered-year annualized cents into this display rate.
  int displayCents(int annualizedCents) =>
      (annualizedCents / annualDivisor).round();
}
