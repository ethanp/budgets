class CategoryTrendPoint {
  const CategoryTrendPoint({
    required this.date,
    required this.rollingCents,
    required this.smoothedCents,
  });

  final DateTime date;

  /// Trailing 30-day spend total ending on [date].
  final double rollingCents;

  /// Heavily smoothed version of [rollingCents] for the trendline.
  final double smoothedCents;
}
