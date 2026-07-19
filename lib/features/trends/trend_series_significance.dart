import 'package:budgets/features/trends/category_trend_series.dart';

/// Whether a series has enough magnitude to show in Trends.
class TrendSeriesSignificance {
  TrendSeriesSignificance._();

  static const minMeaningfulCents = 100.0;

  static bool hasMeaningfulTrend(CategoryTrendSeries series) {
    for (final point in series.points) {
      if (point.smoothedCents.abs() >= minMeaningfulCents ||
          point.rollingCents.abs() >= minMeaningfulCents) {
        return true;
      }
    }
    return false;
  }
}
