import 'dart:math' as math;

import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/trend_spend_rate.dart';
import 'package:spend_trends/features/trends/category_trend_distribution.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/distribution_whisker_painter.dart';
import 'package:spend_trends/features/trends/trend_legend_swatch.dart';
import 'package:spend_trends/features/trends/trend_value_scale.dart';

/// Shared-scale min/med/avg/max/now whiskers for ranked category/group series.
class const CategoryTrendDistributionLegend({
  required final List<CategoryTrendSeries> seriesList,
  required final Set<String> hiddenSeriesIds,
  required final TrendSpendRate spendRate,
  required final ValueChanged<String> onSeriesToggled,
  required final ValueChanged<String> onSeriesSoloed,
}) extends StatelessWidget {
  static const _whiskerHeight = 108.0;
  static const _labelBlockHeight = 66.0;
  static const _columnWidth = 96.0;
  static const _axisWidth = 44.0;
  static const _columnGap = ELayout.spaceSm;
  static const _gridOverhang = 12.0;

  @override
  Widget build(BuildContext context) {
    final pairsBySeriesId = <String, CategoryTrendDistributionPair>{};
    for (final series in seriesList) {
      final pair = distributionPairForSmoothed(series.points);
      if (!pair.isEmpty) {
        pairsBySeriesId[series.id] = pair;
      }
    }

    var dataMaxCents = 0.0;
    for (final pair in pairsBySeriesId.values) {
      for (final distribution in [pair.allTime, pair.pastYear]) {
        if (distribution == null) continue;
        dataMaxCents = math.max(
          dataMaxCents,
          math.max(distribution.maxCents, distribution.currentCents),
        );
      }
    }
    final scale = TrendValueScale.niceForMax(dataMaxCents);

    final columnsWidth = seriesList.isEmpty
        ? 0.0
        : seriesList.length * _columnWidth +
              math.max(0, seriesList.length - 1) * _columnGap;
    final gridWidth = columnsWidth + _gridOverhang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DistributionWhiskerSymbolKey(),
        const SizedBox(height: ELayout.spaceSm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _axisWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: _labelBlockHeight),
                  _DistributionAxisLabels(
                    scale: scale,
                    whiskerHeight: _whiskerHeight,
                    formatTick: _formatAnnualized,
                  ),
                ],
              ),
            ),
            const SizedBox(width: ELayout.spaceXs),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: gridWidth,
                  child: Stack(
                    children: [
                      Positioned(
                        top: _labelBlockHeight,
                        left: 0,
                        width: gridWidth,
                        height: _whiskerHeight,
                        child: CustomPaint(
                          painter: DistributionWhiskerGridPainter(scale: scale),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < seriesList.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: _columnGap),
                            SizedBox(
                              width: _columnWidth,
                              child: _DistributionColumn(
                                series: seriesList[index],
                                pair: pairsBySeriesId[seriesList[index].id],
                                scale: scale,
                                isHidden: hiddenSeriesIds.contains(
                                  seriesList[index].id,
                                ),
                                formatAnnualized: _formatAnnualized,
                                pastYearTotalLabel: _pastYearTotalLabel(
                                  seriesList[index],
                                ),
                                onActivated: () =>
                                    onSeriesToggled(seriesList[index].id),
                                onSoloActivated: () =>
                                    onSeriesSoloed(seriesList[index].id),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatAnnualized(int annualizedCents) {
    return formatCentsWholeDollars(spendRate.displayCents(annualizedCents));
  }

  String _pastYearTotalLabel(CategoryTrendSeries series) {
    if (series.points.isEmpty) return '—';
    final totalCents = series.points.last.rollingCents.round();
    if (totalCents <= 0) return '—';
    return formatCentsWholeDollars(totalCents);
  }
}

class const _DistributionAxisLabels({
  required final TrendValueScale scale,
  required final double whiskerHeight,
  required final String Function(int cents) formatTick,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tickStyle = EText.caption.copyWith(fontSize: 10);
    return SizedBox(
      height: whiskerHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final tickCents in scale.tickCents)
            Positioned(
              top: scale.yFromTop(tickCents, whiskerHeight) - 7,
              right: 0,
              child: Text(
                formatTick(tickCents.round()),
                style: tickStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class const _DistributionColumn({
  required final CategoryTrendSeries series,
  required final CategoryTrendDistributionPair? pair,
  required final TrendValueScale scale,
  required final bool isHidden,
  required final String Function(int cents) formatAnnualized,
  required final String pastYearTotalLabel,
  required final VoidCallback onActivated,
  required final VoidCallback onSoloActivated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nowCents =
        pair?.pastYear?.currentCents ?? pair?.allTime?.currentCents;
    final nowLabel = nowCents == null
        ? '—'
        : formatAnnualized(nowCents.round());
    final periodLabelStyle = EText.caption.copyWith(
      color: isHidden ? EColors.textMuted : EColors.textMuted,
      fontSize: 9,
      height: 1,
    );

    return GestureDetector(
      onTap: onActivated,
      onDoubleTap: onSoloActivated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: CategoryTrendDistributionLegend._labelBlockHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TrendLegendSwatch(series: series, isHidden: isHidden),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        series.name,
                        style: isHidden
                            ? EText.caption.copyWith(
                                color: EColors.textMuted,
                                fontSize: 11,
                              )
                            : EText.caption.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  nowLabel,
                  style: isHidden
                      ? EText.caption.copyWith(color: EColors.textMuted)
                      : EText.caption.copyWith(color: EColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'all',
                        style: periodLabelStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '1y',
                        style: periodLabelStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(
                      child: Text(
                        pastYearTotalLabel,
                        style: isHidden
                            ? EText.caption.copyWith(
                                color: EColors.textMuted,
                                fontSize: 10,
                                height: 1.1,
                              )
                            : EText.caption.copyWith(
                                color: EColors.textSecondary,
                                fontSize: 10,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: CategoryTrendDistributionLegend._whiskerHeight,
            width: double.infinity,
            child: _buildWhiskerPair(),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiskerPair() {
    final distributionPair = pair;
    if (distributionPair == null || distributionPair.isEmpty) {
      return Center(child: Text('—', style: EText.caption));
    }
    return Row(
      children: [
        Expanded(
          child: _DistributionWhisker(
            distribution: distributionPair.allTime,
            scale: scale,
            seriesColor: series.lineColor.withValues(alpha: 0.55),
            isHidden: isHidden,
          ),
        ),
        Expanded(
          child: _DistributionWhisker(
            distribution: distributionPair.pastYear,
            scale: scale,
            seriesColor: series.lineColor,
            isHidden: isHidden,
          ),
        ),
      ],
    );
  }
}

class const _DistributionWhisker({
  required final CategoryTrendDistribution? distribution,
  required final TrendValueScale scale,
  required final Color seriesColor,
  required final bool isHidden,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (distribution == null) {
      return Center(child: Text('—', style: EText.caption));
    }
    return CustomPaint(
      painter: DistributionWhiskerPainter(
        distribution: distribution!,
        scale: scale,
        seriesColor: seriesColor,
        isDimmed: isHidden,
      ),
      child: const SizedBox.expand(),
    );
  }
}
