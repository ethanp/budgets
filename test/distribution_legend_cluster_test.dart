import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_trends/features/trends/category_trend_point.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/distribution_legend_cluster.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';

void main() {
  test('rolls member series under their group and leaves standalones rolled up', () {
    final wants = _series(id: 'group:wants', name: 'Wants');
    final dining = _series(
      id: 'cat_dining',
      name: 'Dining',
      memberOfGroupSeriesId: 'group:wants',
    );
    final travel = _series(
      id: 'cat_travel',
      name: 'Travel',
      memberOfGroupSeriesId: 'group:wants',
    );
    final housing = _series(id: 'cat_housing', name: 'Housing');

    final allSpend = _series(
      id: TrendChartCatalog.allSpendSeriesId,
      name: 'All',
    );
    final clusters = DistributionLegendCluster.fromSeries([
      wants,
      dining,
      travel,
      housing,
      allSpend,
    ]);

    expect(clusters, hasLength(3));
    expect(clusters.first.rollup.id, TrendChartCatalog.allSpendSeriesId);
    expect(clusters.first.canExpand, isFalse);
    expect(clusters[1].rollup.id, 'group:wants');
    expect(clusters[1].canExpand, isTrue);
    expect(
      clusters[1].members.map((series) => series.id),
      ['cat_dining', 'cat_travel'],
    );
    expect(clusters.last.rollup.id, 'cat_housing');
    expect(clusters.last.canExpand, isFalse);
  });
}

CategoryTrendSeries _series({
  required String id,
  required String name,
  String? memberOfGroupSeriesId,
}) {
  return CategoryTrendSeries(
    id: id,
    name: name,
    lineColor: const Color(0xFF00AA00),
    memberOfGroupSeriesId: memberOfGroupSeriesId,
    points: [
      CategoryTrendPoint(
        date: DateTime(2024, 1, 1),
        rollingCents: 100,
        smoothedCents: 100,
      ),
    ],
  );
}
