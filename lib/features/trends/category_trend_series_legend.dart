import 'dart:math' as math;

import 'package:budgets/domain/trend_spend_rate.dart';
import 'package:budgets/features/trends/category_trend_distribution_legend.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:budgets/features/trends/trend_legend_swatch.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:flutter/cupertino.dart';

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
            const SizedBox(width: AppSpacing.md),
            _LegendColumnDivider(
              height: useDistributionLegend ? 140.0 : 72.0,
            ),
            const SizedBox(width: AppSpacing.md),
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

  static bool _isMetaLegendSeries(CategoryTrendSeries series) {
    if (series.id == CategoryTrendSeriesFactory.allSpendSeriesId) return true;
    if (series.id ==
        CategoryTrendSeriesFactory.housingAffordabilitySeriesId) {
      return true;
    }
    if (series.id == CategoryTrendSeriesFactory.uncategorizedSeriesId) {
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
    final cents = series.latestSmoothedCents.round();
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
          ? AppText.body.small.copyWith(color: AppColors.textColor4)
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
          const SizedBox(width: AppSpacing.xs),
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
              if (index > 0) const SizedBox(height: AppSpacing.sm),
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
      if (rowIndex > 0) chips.add(const SizedBox(height: AppSpacing.sm));
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
