import 'package:budgets/features/trends/category_trend_series.dart';

class TrendsChartBundle {
  const TrendsChartBundle({
    required this.categorySpend,
    required this.cashFlows,
    this.netWorth = const [],
  });

  final List<CategoryTrendSeries> categorySpend;
  final List<CategoryTrendSeries> cashFlows;
  final List<CategoryTrendSeries> netWorth;

  bool get isEmpty =>
      categorySpend.isEmpty && cashFlows.isEmpty && netWorth.isEmpty;
}
