import 'package:spend_trends/features/trends/category_trend_series.dart';

/// Group rollup (or standalone category) plus its member series for whiskers.
class const DistributionLegendCluster({
  required final CategoryTrendSeries rollup,
  final List<CategoryTrendSeries> members = const [],
}) {
  bool get canExpand => members.isNotEmpty;

  static List<DistributionLegendCluster> fromSeries(
    List<CategoryTrendSeries> seriesList,
  ) {
    final membersByGroupSeriesId = <String, List<CategoryTrendSeries>>{};
    final rollups = <CategoryTrendSeries>[];
    for (final series in seriesList) {
      final groupSeriesId = series.memberOfGroupSeriesId;
      if (groupSeriesId == null) {
        rollups.add(series);
        continue;
      }
      membersByGroupSeriesId.putIfAbsent(groupSeriesId, () => []).add(series);
    }
    final allSpendClusters = <DistributionLegendCluster>[];
    final rankedClusters = <DistributionLegendCluster>[];
    for (final rollup in rollups) {
      final cluster = DistributionLegendCluster(
        rollup: rollup,
        members: membersByGroupSeriesId[rollup.id] ?? const [],
      );
      if (rollup.isAllSpend) {
        allSpendClusters.add(cluster);
        continue;
      }
      rankedClusters.add(cluster);
    }
    return [...allSpendClusters, ...rankedClusters];
  }
}
