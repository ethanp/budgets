import 'package:budgets/features/trends/category_trend_series.dart';

class TrendsChartBundle {
  const TrendsChartBundle({
    required this.categorySpend,
    required this.cashFlows,
  });

  final List<CategoryTrendSeries> categorySpend;
  final List<CategoryTrendSeries> cashFlows;

  bool get isEmpty => categorySpend.isEmpty && cashFlows.isEmpty;
}
