import 'dart:math' as math;

import 'package:spend_trends/domain/trend_spend_rate.dart';
import 'package:spend_trends/features/trends/category_trend_distribution_legend.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/trend_legend_swatch.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/util/money_format.dart';
import 'package:flutter/cupertino.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';

/// Legend under a trends chart: meta chips, plus ranked chips or distribution.
class CategoryTrendSeriesLegend extends StatelessWidget {
  const CategoryTrendSeriesLegend({
    super.key,
    required this.seriesList,
    required this.hiddenSeriesIds,
    required this.spendRate,
    required this.useDistributionLegend,
    required this.onToggleSeries,
    required this.onSoloSeries,
    this.valueKind = TrendValueKind.pace,
  });

  final List<CategoryTrendSeries> seriesList;
  final Set<String> hiddenSeriesIds;
  final TrendSpendRate spendRate;
  final TrendValueKind valueKind;
  final bool useDistributionLegend;
  final ValueChanged<String> onToggleSeries;
  final ValueChanged<String> onSoloSeries;

  @override
  Widget build(BuildContext context) {
    if (seriesList.isEmpty) return const SizedBox.shrink();

    final metaSeries = [
      for (final series in seriesList)
        if (_isMetaLegendSeries(series)) series,
    ];
    final rankedSeries = [
      for (final series in seriesList)
        if (!_isMetaLegendSeries(series)) series,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metaSeries.isNotEmpty) ...[
          _MetaLegendColumn(
            metaSeries: metaSeries,
            hiddenSeriesIds: hiddenSeriesIds,
            spendRate: spendRate,
            valueKind: valueKind,
            onToggleSeries: onToggleSeries,
            onSoloSeries: onSoloSeries,
          ),
          if (rankedSeries.isNotEmpty) ...[
            HSpace.md,
            _LegendColumnDivider(
              height: useDistributionLegend ? 140.0 : 72.0,
            ),
            HSpace.md,
          ],
        ],
        if (rankedSeries.isNotEmpty)
          Expanded(
            child: useDistributionLegend
                ? CategoryTrendDistributionLegend(
                    seriesList: rankedSeries,
                    hiddenSeriesIds: hiddenSeriesIds,
                    spendRate: spendRate,
                    onToggleSeries: onToggleSeries,
                    onSoloSeries: onSoloSeries,
                  )
                : _rankedSeriesHasLegendGroups(rankedSeries)
                    ? _SectionGroupedLegend(
                        seriesList: rankedSeries,
                        hiddenSeriesIds: hiddenSeriesIds,
                        spendRate: spendRate,
                        valueKind: valueKind,
                        onToggleSeries: onToggleSeries,
                        onSoloSeries: onSoloSeries,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => _ColumnMajorLegend(
                          seriesList: rankedSeries,
                          maxWidth: constraints.maxWidth,
                          hiddenSeriesIds: hiddenSeriesIds,
                          spendRate: spendRate,
                          valueKind: valueKind,
                          onToggleSeries: onToggleSeries,
                          onSoloSeries: onSoloSeries,
                        ),
                      ),
          ),
      ],
    );
  }

  static bool _rankedSeriesHasLegendGroups(List<CategoryTrendSeries> seriesList) {
    for (final series in seriesList) {
      if (series.legendGroup != null) return true;
    }
    return false;
  }

  static bool _isMetaLegendSeries(CategoryTrendSeries series) {
    if (series.id == TrendChartCatalog.allSpendSeriesId) return true;
    if (series.id == TrendChartCatalog.netWorthSeriesId) return true;
    if (series.id ==
        TrendChartCatalog.housingAffordabilitySeriesId) {
      return true;
    }
    if (series.id == TrendChartCatalog.uncategorizedSeriesId) {
      return true;
    }
    return series.id == 'cat_other' || series.name.toLowerCase() == 'other';
  }
}

class TrendLegendChip extends StatelessWidget {
  const TrendLegendChip({
    super.key,
    required this.series,
    required this.isHidden,
    required this.spendRate,
    required this.onToggle,
    required this.onSolo,
    this.valueKind = TrendValueKind.pace,
    this.expandLabel = true,
  });

  final CategoryTrendSeries series;
  final bool isHidden;
  final TrendSpendRate spendRate;
  final TrendValueKind valueKind;
  final VoidCallback onToggle;
  final VoidCallback onSolo;
  final bool expandLabel;

  @override
  Widget build(BuildContext context) {
    // Level charts (net worth): show current rolling balance, not CMA tip —
    // the tip window averages prior days and drifts from today's Banks total.
    final cents = (valueKind == TrendValueKind.level
            ? series.latestRollingCents
            : series.latestSmoothedCents)
        .round();
    final amountLabel = formatCentsWholeDollars(
      valueKind == TrendValueKind.level
          ? cents
          : spendRate.displayCents(cents),
    );
    final rateSuffix = valueKind == TrendValueKind.level
        ? ''
        : ' ${spendRate.shortLabel}';
    final label = Text(
      '${series.name} · $amountLabel$rateSuffix',
      style: isHidden
          ? AppText.body.small.copyWith(color: AppColors.textDim)
          : AppText.body.small,
      maxLines: 1,
      softWrap: false,
      overflow: expandLabel ? TextOverflow.ellipsis : TextOverflow.visible,
    );
    return GestureDetector(
      onTap: onToggle,
      onDoubleTap: onSolo,
      child: Row(
        mainAxisSize: expandLabel ? MainAxisSize.max : MainAxisSize.min,
        children: [
          TrendLegendSwatch(series: series, isHidden: isHidden),
          HSpace.xs,
          if (expandLabel) Expanded(child: label) else label,
        ],
      ),
    );
  }
}

class _MetaLegendColumn extends StatelessWidget {
  const _MetaLegendColumn({
    required this.metaSeries,
    required this.hiddenSeriesIds,
    required this.spendRate,
    required this.valueKind,
    required this.onToggleSeries,
    required this.onSoloSeries,
  });

  final List<CategoryTrendSeries> metaSeries;
  final Set<String> hiddenSeriesIds;
  final TrendSpendRate spendRate;
  final TrendValueKind valueKind;
  final ValueChanged<String> onToggleSeries;
  final ValueChanged<String> onSoloSeries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth1.withValues(alpha: 0.7)),
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < metaSeries.length; index++) ...[
              if (index > 0) VSpace.sm,
              TrendLegendChip(
                series: metaSeries[index],
                isHidden: hiddenSeriesIds.contains(metaSeries[index].id),
                spendRate: spendRate,
                valueKind: valueKind,
                expandLabel: false,
                onToggle: () => onToggleSeries(metaSeries[index].id),
                onSolo: () => onSoloSeries(metaSeries[index].id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendColumnDivider extends StatelessWidget {
  const _LegendColumnDivider({this.height = 72});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      color: AppColors.borderDepth1.withValues(alpha: 0.8),
    );
  }
}

class _ColumnMajorLegend extends StatelessWidget {
  const _ColumnMajorLegend({
    required this.seriesList,
    required this.maxWidth,
    required this.hiddenSeriesIds,
    required this.spendRate,
    required this.valueKind,
    required this.onToggleSeries,
    required this.onSoloSeries,
  });

  final List<CategoryTrendSeries> seriesList;
  final double maxWidth;
  final Set<String> hiddenSeriesIds;
  final TrendSpendRate spendRate;
  final TrendValueKind valueKind;
  final ValueChanged<String> onToggleSeries;
  final ValueChanged<String> onSoloSeries;

  @override
  Widget build(BuildContext context) {
    const minColumnWidth = 148.0;
    const columnGap = AppSpacing.md;
    final columnCount = math.max(
      1,
      ((maxWidth + columnGap) / (minColumnWidth + columnGap)).floor(),
    );
    final rowCount = (seriesList.length + columnCount - 1) ~/ columnCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) ...[
          if (columnIndex > 0) const SizedBox(width: columnGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _chipsForColumn(
                columnIndex: columnIndex,
                rowCount: rowCount,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _chipsForColumn({
    required int columnIndex,
    required int rowCount,
  }) {
    final chips = <Widget>[];
    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final seriesIndex = columnIndex * rowCount + rowIndex;
      if (seriesIndex >= seriesList.length) break;
      if (rowIndex > 0) chips.add(VSpace.sm);
      final series = seriesList[seriesIndex];
      chips.add(
        TrendLegendChip(
          series: series,
          isHidden: hiddenSeriesIds.contains(series.id),
          spendRate: spendRate,
          valueKind: valueKind,
          onToggle: () => onToggleSeries(series.id),
          onSolo: () => onSoloSeries(series.id),
        ),
      );
    }
    return chips;
  }
}

/// Account chips grouped under section headers (account kind for net worth).
///
/// Section order follows first appearance in [seriesList].
class _SectionGroupedLegend extends StatelessWidget {
  const _SectionGroupedLegend({
    required this.seriesList,
    required this.hiddenSeriesIds,
    required this.spendRate,
    required this.valueKind,
    required this.onToggleSeries,
    required this.onSoloSeries,
  });

  final List<CategoryTrendSeries> seriesList;
  final Set<String> hiddenSeriesIds;
  final TrendSpendRate spendRate;
  final TrendValueKind valueKind;
  final ValueChanged<String> onToggleSeries;
  final ValueChanged<String> onSoloSeries;

  @override
  Widget build(BuildContext context) {
    final groups = _groupsFromSeries(seriesList);
    final showSectionLabels = groups.length > 1 ||
        (groups.length == 1 && groups.first.sectionName != 'Other');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
          if (groupIndex > 0) VSpace.md,
          if (showSectionLabels) ...[
            Text(
              groups[groupIndex].sectionName,
              style: AppText.body.small.semibold.accent,
            ),
            VSpace.xs,
          ],
          for (var seriesIndex = 0;
              seriesIndex < groups[groupIndex].seriesList.length;
              seriesIndex++) ...[
            if (seriesIndex > 0) VSpace.sm,
            TrendLegendChip(
              series: groups[groupIndex].seriesList[seriesIndex],
              isHidden: hiddenSeriesIds.contains(
                groups[groupIndex].seriesList[seriesIndex].id,
              ),
              spendRate: spendRate,
              valueKind: valueKind,
              onToggle: () => onToggleSeries(
                groups[groupIndex].seriesList[seriesIndex].id,
              ),
              onSolo: () => onSoloSeries(
                groups[groupIndex].seriesList[seriesIndex].id,
              ),
            ),
          ],
        ],
      ],
    );
  }

  static List<_LegendSectionGroup> _groupsFromSeries(
    List<CategoryTrendSeries> seriesList,
  ) {
    final byName = <String, List<CategoryTrendSeries>>{};
    final sectionOrder = <String>[];
    for (final series in seriesList) {
      final key = series.legendGroup?.trim();
      final sectionName = key == null || key.isEmpty ? 'Other' : key;
      if (!byName.containsKey(sectionName)) {
        sectionOrder.add(sectionName);
        byName[sectionName] = [];
      }
      byName[sectionName]!.add(series);
    }
    return [
      for (final name in sectionOrder)
        _LegendSectionGroup(
          sectionName: name,
          seriesList: byName[name]!,
        ),
    ];
  }
}

class _LegendSectionGroup {
  const _LegendSectionGroup({
    required this.sectionName,
    required this.seriesList,
  });

  final String sectionName;
  final List<CategoryTrendSeries> seriesList;
}
