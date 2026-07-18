import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:flutter/cupertino.dart';

class CategoryTrendSeries {
  const CategoryTrendSeries({
    required this.id,
    required this.name,
    required this.lineColor,
    required this.points,
    this.dotted = false,
    this.percentileAreaFill = false,
  });

  /// Category id, or `'__all__'` for total spend.
  final String id;
  final String name;
  final Color lineColor;
  final List<CategoryTrendPoint> points;

  /// Total-spend overlay uses a dotted stroke so it reads apart from categories.
  final bool dotted;

  /// Fill under the line; opacity encodes each point's percentile in the series.
  final bool percentileAreaFill;

  double get latestSmoothedCents =>
      points.isEmpty ? 0 : points.last.smoothedCents;
}
