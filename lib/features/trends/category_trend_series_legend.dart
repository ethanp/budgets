import 'dart:math' as math;

import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/account_kind.dart';
import 'package:spend_trends/domain/trend_spend_rate.dart';
import 'package:spend_trends/features/trends/category_trend_distribution_legend.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';
import 'package:spend_trends/features/trends/trend_legend_swatch.dart';
import 'package:spend_trends/theme/finance_colors.dart';

/// Legend under a trends chart: meta chips, plus ranked chips or distribution.
class CategoryTrendSeriesLegend extends StatelessWidget {
  const CategoryTrendSeriesLegend({
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

    final useNetWorthTable = !useDistributionLegend &&
        _rankedSeriesHasLegendGroups(rankedSeries);
    final needsWidthLayout = rankedSeries.isNotEmpty &&
        !useDistributionLegend &&
        !useNetWorthTable;

    final rankedChild = rankedSeries.isEmpty
        ? null
        : useDistributionLegend
            ? CategoryTrendDistributionLegend(
                seriesList: rankedSeries,
                hiddenSeriesIds: hiddenSeriesIds,
                spendRate: spendRate,
                onToggleSeries: onToggleSeries,
                onSoloSeries: onSoloSeries,
              )
            : useNetWorthTable
                ? _NetWorthLegendTable(
                    seriesList: rankedSeries,
                    hiddenSeriesIds: hiddenSeriesIds,
                    valueKind: valueKind,
                    onToggleSeries: onToggleSeries,
                    onSoloSeries: onSoloSeries,
                  )
                : null;

    final row = Row(
      crossAxisAlignment: needsWidthLayout
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
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
            const SizedBox(width: AppMetrics.spaceMd),
            _LegendColumnDivider(height: needsWidthLayout ? 72 : null),
            const SizedBox(width: AppMetrics.spaceMd),
          ],
        ],
        if (rankedSeries.isNotEmpty)
          Expanded(
            child: needsWidthLayout
                ? LayoutBuilder(
                    builder: (context, constraints) => _ColumnMajorLegend(
                      seriesList: rankedSeries,
                      maxWidth: constraints.maxWidth,
                      hiddenSeriesIds: hiddenSeriesIds,
                      spendRate: spendRate,
                      valueKind: valueKind,
                      onToggleSeries: onToggleSeries,
                      onSoloSeries: onSoloSeries,
                    ),
                  )
                : rankedChild!,
          ),
      ],
    );

    // LayoutBuilder cannot sit under IntrinsicHeight.
    if (needsWidthLayout) return row;
    return IntrinsicHeight(child: row);
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
    return series.isOtherCategory;
  }
}

class TrendLegendChip extends StatelessWidget {
  const TrendLegendChip({
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
    final cents = _legendDisplayCents(series, valueKind: valueKind);
    final amountLabel = formatCentsWholeDollars(
      valueKind == TrendValueKind.level
          ? cents
          : spendRate.displayCents(cents),
    );
    final rateSuffix = valueKind == TrendValueKind.level
        ? ''
        : ' ${spendRate.shortLabel}';
    final nameStyle = isHidden
        ? AppText.caption.copyWith(color: AppColors.textMuted)
        : AppText.caption;
    final amountStyle = valueKind == TrendValueKind.level
        ? _signedAmountStyle(cents, isHidden: isHidden)
        : nameStyle;
    final label = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: series.name, style: nameStyle),
          TextSpan(text: ' · ', style: nameStyle),
          TextSpan(text: '$amountLabel$rateSuffix', style: amountStyle),
        ],
      ),
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
          const SizedBox(width: AppMetrics.spaceXs),
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
        horizontal: AppMetrics.spaceSm,
        vertical: AppMetrics.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < metaSeries.length; index++) ...[
              if (index > 0) const SizedBox(height: AppMetrics.spaceSm),
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
  const _LegendColumnDivider({this.height});

  /// Fixed height when the parent cannot stretch (e.g. beside a [LayoutBuilder]).
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      color: AppColors.border.withValues(alpha: 0.8),
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
    const columnGap = AppMetrics.spaceMd;
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
      if (rowIndex > 0) chips.add(const SizedBox(height: AppMetrics.spaceSm));
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

/// Net worth account rows as a signed-amount table, grouped by account kind.
class _NetWorthLegendTable extends StatelessWidget {
  const _NetWorthLegendTable({
    required this.seriesList,
    required this.hiddenSeriesIds,
    required this.valueKind,
    required this.onToggleSeries,
    required this.onSoloSeries,
  });

  final List<CategoryTrendSeries> seriesList;
  final Set<String> hiddenSeriesIds;
  final TrendValueKind valueKind;
  final ValueChanged<String> onToggleSeries;
  final ValueChanged<String> onSoloSeries;

  @override
  Widget build(BuildContext context) {
    final groups = _groupsFromSeries(seriesList);
    final showSectionLabels = groups.length > 1 ||
        (groups.length == 1 && groups.first.sectionName != 'Other');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.spaceSm,
        vertical: AppMetrics.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(),
          1: IntrinsicColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
            if (showSectionLabels)
              _sectionHeaderRow(
                groups[groupIndex].sectionName,
                padTop: groupIndex > 0,
              ),
            for (final series in groups[groupIndex].seriesList)
              _accountRow(series),
          ],
        ],
      ),
    );
  }

  TableRow _sectionHeaderRow(String sectionName, {required bool padTop}) {
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: padTop ? AppMetrics.spaceSm : 0,
            bottom: AppMetrics.spaceXs,
          ),
          child: Text(
            sectionName,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: FinanceColors.accentPrimary,
            ),
          ),
        ),
        const SizedBox.shrink(),
      ],
    );
  }

  TableRow _accountRow(CategoryTrendSeries series) {
    final isHidden = hiddenSeriesIds.contains(series.id);
    final cents = _legendDisplayCents(series, valueKind: valueKind);
    return TableRow(
      children: [
        GestureDetector(
          onTap: () => onToggleSeries(series.id),
          onDoubleTap: () => onSoloSeries(series.id),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppMetrics.spaceXs),
            child: Row(
              children: [
                TrendLegendSwatch(series: series, isHidden: isHidden),
                const SizedBox(width: AppMetrics.spaceSm),
                Expanded(
                  child: Text(
                    series.name,
                    style: isHidden
                        ? AppText.caption.copyWith(color: AppColors.textMuted)
                        : AppText.caption.copyWith(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onToggleSeries(series.id),
          onDoubleTap: () => onSoloSeries(series.id),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppMetrics.spaceMd,
              top: AppMetrics.spaceXs,
              bottom: AppMetrics.spaceXs,
            ),
            child: Text(
              formatCentsWholeDollars(cents),
              style: _signedAmountStyle(cents, isHidden: isHidden).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ),
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
          seriesList: _sortedByMagnitudeDesc(byName[name]!),
        ),
    ];
  }

  static List<CategoryTrendSeries> _sortedByMagnitudeDesc(
    List<CategoryTrendSeries> seriesList,
  ) {
    final sorted = [...seriesList];
    sorted.sort((left, right) {
      final leftCents = _legendDisplayCents(
        left,
        valueKind: TrendValueKind.level,
      ).abs();
      final rightCents = _legendDisplayCents(
        right,
        valueKind: TrendValueKind.level,
      ).abs();
      return rightCents.compareTo(leftCents);
    });
    return sorted;
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

int _legendDisplayCents(
  CategoryTrendSeries series, {
  required TrendValueKind valueKind,
}) {
  final raw = valueKind == TrendValueKind.level
      ? series.latestRollingCents
      : series.latestSmoothedCents;
  final cents = raw.round();
  // Net worth liabilities are plotted as abs magnitude (often with a dotted
  // stroke). Restore a signed debt for legend amounts / colors.
  if (valueKind == TrendValueKind.level && _isNetWorthLiability(series)) {
    return -cents.abs();
  }
  return cents;
}

bool _isNetWorthLiability(CategoryTrendSeries series) {
  if (series.dotted) return true;
  final group = series.legendGroup;
  return group == AccountKind.creditCard.legendLabel ||
      group == AccountKind.loans.legendLabel;
}

TextStyle _signedAmountStyle(int cents, {required bool isHidden}) {
  final base = AppText.caption.copyWith(fontWeight: FontWeight.w600);
  if (isHidden) {
    return base.copyWith(color: AppColors.textMuted);
  }
  if (cents > 0) return base.copyWith(color: AppColors.success);
  if (cents < 0) return base.copyWith(color: AppColors.danger);
  return base;
}
