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

  /// Convert trailing-year annualized cents into this display rate.
  int displayCents(int annualizedCents) => switch (this) {
        TrendSpendRate.perYear => annualizedCents,
        TrendSpendRate.perMonth => (annualizedCents / 12).round(),
        TrendSpendRate.perDay => (annualizedCents / 365).round(),
      };
}
