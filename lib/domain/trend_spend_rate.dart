/// Whether a Trends chart plots annualized pace or absolute dollar levels.
enum TrendValueKind {
  /// Centered-year spend / cash-flow pace (yr/mo/day toggle applies).
  pace,

  /// Point-in-time dollars (e.g. net worth); no rate scaling.
  level,
}

/// Display rate for Trends legend / inspect amounts (chart series stay annualized).
enum TrendSpendRate {
  perYear,
  perMonth,
  perDay;

  String get shortLabel => switch (this) {
    TrendSpendRate.perYear => '/ yr',
    TrendSpendRate.perMonth => '/ mo',
    TrendSpendRate.perDay => '/ day',
  };

  String get toggleLabel => switch (this) {
    TrendSpendRate.perYear => 'yr',
    TrendSpendRate.perMonth => 'mo',
    TrendSpendRate.perDay => 'day',
  };

  /// Convert centered-year annualized cents into this display rate.
  int displayCents(int annualizedCents) => switch (this) {
    TrendSpendRate.perYear => annualizedCents,
    TrendSpendRate.perMonth => (annualizedCents / 12).round(),
    TrendSpendRate.perDay => (annualizedCents / 365).round(),
  };
}
