import 'package:spend_trends/features/trends/category_trend_series.dart';

class const TrendsChartBundle({
  required final List<CategoryTrendSeries> categorySpend,
  required final List<CategoryTrendSeries> cashFlows,
  final List<CategoryTrendSeries> netWorth = const [],
}) {
  bool get isEmpty =>
      categorySpend.isEmpty && cashFlows.isEmpty && netWorth.isEmpty;
}
