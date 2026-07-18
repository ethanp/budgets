class CategoryTrendPoint {
  const CategoryTrendPoint({
    required this.date,
    required this.rollingCents,
    required this.smoothedCents,
  });

  final DateTime date;

  /// Trailing-year spend ending on [date], scaled up if fewer than 365
  /// observed days exist yet (partial first year).
  final double rollingCents;

  /// Heavily smoothed version of [rollingCents] for the trendline.
  final double smoothedCents;
}
