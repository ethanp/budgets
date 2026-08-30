import 'package:flutter/material.dart';
import 'package:spend_trends/features/trends/category_trend_point.dart';

class const CategoryTrendSeries({
  /// Category id, or `'__all__'` for total spend.
  required final String id,
  required final String name,
  required final Color lineColor,
  required final List<CategoryTrendPoint> points,

  /// Total-spend overlay uses a dotted stroke so it reads apart from categories.
  final bool dotted = false,

  /// Thin long-dash reference line (e.g. affordability threshold).
  final bool guide = false,

  /// Fill under the line; opacity encodes each point's percentile in the series.
  final bool percentileAreaFill = false,

  /// Optional legend section header (e.g. bank institution for net worth).
  final String? legendGroup,
}) {
  double get latestSmoothedCents =>
      points.isEmpty ? 0 : points.last.smoothedCents;

  double get latestRollingCents =>
      points.isEmpty ? 0 : points.last.rollingCents;

  static const minMeaningfulCents = 100.0;

  /// Enough magnitude to show in Trends (smoothed or rolling).
  bool get hasMeaningfulTrend {
    for (final point in points) {
      if (point.smoothedCents.abs() >= minMeaningfulCents ||
          point.rollingCents.abs() >= minMeaningfulCents) {
        return true;
      }
    }
    return false;
  }

  /// Catch-all "Other" category series (by id or display name).
  bool get isOtherCategory =>
      id == 'cat_other' || name.toLowerCase() == 'other';
}
