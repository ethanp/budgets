import 'dart:math' as math;

import 'package:budgets/domain/life_event.dart';
import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/domain/trend_spend_rate.dart';
import 'package:budgets/features/trends/category_trend_distribution.dart';
import 'package:budgets/features/trends/category_trend_painter.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:budgets/features/trends/distribution_whisker_painter.dart';
import 'package:budgets/features/trends/trend_value_scale.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// One SimCity-style multi-line chart with a color legend.
class CategoryTrendChart extends ConsumerStatefulWidget {
  const CategoryTrendChart({
    super.key,
    required this.title,
    required this.seriesList,
    this.lifeEvents = const [],
    this.homebaseChain,
    this.jobChain,
    this.subtitle =
        'Trailing year · tap legend to show/hide · double-tap to solo',
    this.initiallyHiddenSeriesIds = const {},
    this.showSpendRateToggle = false,
    this.useDistributionLegend = false,
  });

  final String title;
  final String subtitle;
  final List<CategoryTrendSeries> seriesList;
  final List<LifeEvent> lifeEvents;
  final StayChain? homebaseChain;
  final StayChain? jobChain;
  final Set<String> initiallyHiddenSeriesIds;

  /// When true, shows the shared yr/mo/day control (only one chart should).
  final bool showSpendRateToggle;

  /// Shared-scale min/med/avg/max/now whiskers for ranked category/group series.
  final bool useDistributionLegend;

  @override
  ConsumerState<CategoryTrendChart> createState() => _CategoryTrendChartState();
}

class _CategoryTrendChartState extends ConsumerState<CategoryTrendChart> {
  late final Set<String> _hiddenSeriesIds = {
    ...widget.initiallyHiddenSeriesIds,
  };
  Offset? _hoverPosition;
  DateTime? _hoverDate;

  List<CategoryTrendSeries> get _visibleSeries => widget.seriesList
      .where((series) => !_hiddenSeriesIds.contains(series.id))
      .toList();

  TrendSpendRate get _spendRate => ref.watch(trendSpendRateProvider);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: AppText.body.large.semibold),
              ),
              if (widget.showSpendRateToggle) _spendRateToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.subtitle, style: AppText.caption),
          const SizedBox(height: AppSpacing.md),
          _chartArea(),
          const SizedBox(height: AppSpacing.sm),
          _inspectCaption(),
          const SizedBox(height: AppSpacing.md),
          _legend(),
        ],
      ),
    );
  }

  Widget _spendRateToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final rate in TrendSpendRate.values) ...[
          if (rate != TrendSpendRate.values.first)
            const SizedBox(width: AppSpacing.xs),
          _spendRateChip(rate),
        ],
      ],
    );
  }

  Widget _spendRateChip(TrendSpendRate rate) {
    final isSelected = _spendRate == rate;
    return GestureDetector(
      onTap: () => ref.read(trendSpendRateProvider.notifier).setRate(rate),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withValues(alpha: 0.25)
              : AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDepth1,
          ),
        ),
        child: Text(
          rate.toggleLabel,
          style: AppText.body.small.copyWith(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.textColor3,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _formatAnnualized(int annualizedCents) {
    return formatCentsWholeDollars(_spendRate.displayCents(annualizedCents));
  }

  /// Trailing-year window total (not yr/mo/day rate).
  String _pastYearTotalLabel(CategoryTrendSeries series) {
    if (series.points.isEmpty) return '—';
    final totalCents = series.points.last.rollingCents.round();
    if (totalCents <= 0) return '—';
    return formatCentsWholeDollars(totalCents);
  }

  Widget _chartArea() {
    if (!_visibleSeries.any((series) => series.points.length >= 2)) {
      return const SizedBox(
        height: 280,
        child: Center(
          child: Text('Need more history', style: AppText.caption),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) =>
                _updateHover(details.localPosition, constraints),
            onPanUpdate: (details) =>
                _updateHover(details.localPosition, constraints),
            onPanEnd: (_) => _clearHover(),
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: CategoryTrendPainter(
                seriesList: _visibleSeries,
                lifeEvents: widget.lifeEvents,
                homebaseChain: widget.homebaseChain,
                jobChain: widget.jobChain,
                hoverPosition: _hoverPosition,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inspectCaption() {
    final hoverDate = _hoverDate;
    if (hoverDate == null) {
      return const Text(
        'Drag to inspect all lines at a date',
        style: AppText.caption,
      );
    }

    final values = _visibleSeries.map((series) {
      final point = _nearestPoint(series.points, hoverDate);
      final amount = point == null
          ? '—'
          : _formatAnnualized(point.smoothedCents.round());
      return '${series.name} $amount';
    }).join(' · ');

    return Text(
      '${DateFormat.MMMd().format(hoverDate)} · $values '
      '(${_spendRate.shortLabel.trim()})',
      style: AppText.caption,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Meta series (All / Other / Uncategorized) in a separated column; remaining
  /// categories use chips or shared-scale distribution whiskers.
  Widget _legend() {
    final seriesList = widget.seriesList;
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
          _metaLegendColumn(metaSeries),
          if (rankedSeries.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.md),
            _legendColumnDivider(
              height: widget.useDistributionLegend ? 140.0 : 72.0,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
        ],
        if (rankedSeries.isNotEmpty)
          Expanded(
            child: widget.useDistributionLegend
                ? _distributionLegend(rankedSeries)
                : LayoutBuilder(
                    builder: (context, constraints) => _columnMajorLegend(
                      seriesList: rankedSeries,
                      maxWidth: constraints.maxWidth,
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _distributionLegend(List<CategoryTrendSeries> seriesList) {
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

    const whiskerHeight = 108.0;
    const labelBlockHeight = 66.0;
    const columnWidth = 96.0;
    const axisWidth = 44.0;
    const columnGap = AppSpacing.sm;
    // Stop guides just past the last whisker, not at the viewport edge.
    const gridOverhang = 12.0;
    final columnsWidth = seriesList.isEmpty
        ? 0.0
        : seriesList.length * columnWidth +
            math.max(0, seriesList.length - 1) * columnGap;
    final gridWidth = columnsWidth + gridOverhang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DistributionWhiskerSymbolKey(),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: axisWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: labelBlockHeight),
                  _distributionAxisLabels(
                    scale: scale,
                    whiskerHeight: whiskerHeight,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: gridWidth,
                  child: Stack(
                    children: [
                      Positioned(
                        top: labelBlockHeight,
                        left: 0,
                        width: gridWidth,
                        height: whiskerHeight,
                        child: CustomPaint(
                          painter: DistributionWhiskerGridPainter(scale: scale),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var index = 0;
                              index < seriesList.length;
                              index++) ...[
                            if (index > 0) const SizedBox(width: columnGap),
                            SizedBox(
                              width: columnWidth,
                              child: _distributionColumn(
                                series: seriesList[index],
                                pair: pairsBySeriesId[seriesList[index].id],
                                scale: scale,
                                whiskerHeight: whiskerHeight,
                                labelBlockHeight: labelBlockHeight,
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

  Widget _distributionAxisLabels({
    required TrendValueScale scale,
    required double whiskerHeight,
  }) {
    final tickStyle = AppText.caption.copyWith(fontSize: 10);
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
                _formatAnnualized(tickCents.round()),
                style: tickStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _distributionColumn({
    required CategoryTrendSeries series,
    required CategoryTrendDistributionPair? pair,
    required TrendValueScale scale,
    required double whiskerHeight,
    required double labelBlockHeight,
  }) {
    final isHidden = _hiddenSeriesIds.contains(series.id);
    final nowCents =
        pair?.pastYear?.currentCents ?? pair?.allTime?.currentCents;
    final nowLabel =
        nowCents == null ? '—' : _formatAnnualized(nowCents.round());
    final periodLabelStyle = AppText.caption.copyWith(
      color: isHidden ? AppColors.textColor4 : AppColors.textColor3,
      fontSize: 9,
      height: 1,
    );

    return GestureDetector(
      onTap: () => _toggleSeries(series.id),
      onDoubleTap: () => _soloSeries(series.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: labelBlockHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _legendSwatch(series, isHidden),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        series.name,
                        style: isHidden
                            ? AppText.body.small.copyWith(
                                color: AppColors.textColor4,
                                fontSize: 11,
                              )
                            : AppText.body.small.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  nowLabel,
                  style: isHidden
                      ? AppText.caption.copyWith(color: AppColors.textColor4)
                      : AppText.caption.copyWith(color: AppColors.textColor2),
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
                        _pastYearTotalLabel(series),
                        style: isHidden
                            ? AppText.caption.copyWith(
                                color: AppColors.textColor4,
                                fontSize: 10,
                                height: 1.1,
                              )
                            : AppText.caption.copyWith(
                                color: AppColors.textColor2,
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
            height: whiskerHeight,
            width: double.infinity,
            child: pair == null || pair.isEmpty
                ? const Center(
                    child: Text('—', style: AppText.caption),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _distributionWhisker(
                          distribution: pair.allTime,
                          scale: scale,
                          seriesColor: series.lineColor.withValues(alpha: 0.55),
                          isHidden: isHidden,
                        ),
                      ),
                      Expanded(
                        child: _distributionWhisker(
                          distribution: pair.pastYear,
                          scale: scale,
                          seriesColor: series.lineColor,
                          isHidden: isHidden,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _distributionWhisker({
    required CategoryTrendDistribution? distribution,
    required TrendValueScale scale,
    required Color seriesColor,
    required bool isHidden,
  }) {
    if (distribution == null) {
      return const Center(child: Text('—', style: AppText.caption));
    }
    return CustomPaint(
      painter: DistributionWhiskerPainter(
        distribution: distribution,
        scale: scale,
        seriesColor: seriesColor,
        isDimmed: isHidden,
      ),
      child: const SizedBox.expand(),
    );
  }

  bool _isMetaLegendSeries(CategoryTrendSeries series) {
    if (series.id == CategoryTrendSeriesFactory.allSpendSeriesId) return true;
    if (series.id == CategoryTrendSeriesFactory.uncategorizedSeriesId) {
      return true;
    }
    return series.id == 'cat_other' || series.name.toLowerCase() == 'other';
  }

  Widget _metaLegendColumn(List<CategoryTrendSeries> metaSeries) {
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
              _legendChip(metaSeries[index], expandLabel: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legendColumnDivider({double height = 72}) {
    return Container(
      width: 1,
      height: height,
      color: AppColors.borderDepth1.withValues(alpha: 0.8),
    );
  }

  Widget _columnMajorLegend({
    required List<CategoryTrendSeries> seriesList,
    required double maxWidth,
  }) {
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
              children: [
                for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
                  if (columnIndex * rowCount + rowIndex < seriesList.length) ...[
                    if (rowIndex > 0) const SizedBox(height: AppSpacing.sm),
                    _legendChip(
                      seriesList[columnIndex * rowCount + rowIndex],
                    ),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _legendChip(
    CategoryTrendSeries series, {
    bool expandLabel = true,
  }) {
    final isHidden = _hiddenSeriesIds.contains(series.id);
    final label = Text(
      '${series.name} · '
      '${_formatAnnualized(series.latestSmoothedCents.round())} '
      '${_spendRate.shortLabel}',
      style: isHidden
          ? AppText.body.small.copyWith(color: AppColors.textColor4)
          : AppText.body.small,
      maxLines: 1,
      softWrap: false,
      overflow: expandLabel ? TextOverflow.ellipsis : TextOverflow.visible,
    );
    return GestureDetector(
      onTap: () => _toggleSeries(series.id),
      onDoubleTap: () => _soloSeries(series.id),
      child: Row(
        mainAxisSize: expandLabel ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _legendSwatch(series, isHidden),
          const SizedBox(width: AppSpacing.xs),
          if (expandLabel) Expanded(child: label) else label,
        ],
      ),
    );
  }

  Widget _legendSwatch(CategoryTrendSeries series, bool isHidden) {
    final color = isHidden ? AppColors.textColor4 : series.lineColor;
    if (!series.dotted) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return SizedBox(
      width: 16,
      height: 10,
      child: CustomPaint(painter: _DottedLegendSwatchPainter(color)),
    );
  }

  void _toggleSeries(String seriesId) {
    setState(() {
      if (_hiddenSeriesIds.contains(seriesId)) {
        _hiddenSeriesIds.remove(seriesId);
      } else {
        _hiddenSeriesIds.add(seriesId);
      }
    });
  }

  /// Hide every series except [seriesId]. Double-tap again to restore defaults.
  void _soloSeries(String seriesId) {
    setState(() {
      if (_isSoloed(seriesId)) {
        _hiddenSeriesIds
          ..clear()
          ..addAll(widget.initiallyHiddenSeriesIds);
        return;
      }
      _hiddenSeriesIds
        ..clear()
        ..addAll(
          widget.seriesList
              .where((series) => series.id != seriesId)
              .map((series) => series.id),
        );
    });
  }

  bool _isSoloed(String seriesId) {
    for (final series in widget.seriesList) {
      final isHidden = _hiddenSeriesIds.contains(series.id);
      if (series.id == seriesId) {
        if (isHidden) return false;
      } else if (!isHidden) {
        return false;
      }
    }
    return true;
  }

  void _updateHover(Offset position, BoxConstraints constraints) {
    final hoverDate = _dateForPosition(position, constraints);
    setState(() {
      _hoverPosition = position;
      _hoverDate = hoverDate;
    });
  }

  void _clearHover() {
    if (_hoverPosition == null && _hoverDate == null) return;
    setState(() {
      _hoverPosition = null;
      _hoverDate = null;
    });
  }

  DateTime? _dateForPosition(Offset position, BoxConstraints constraints) {
    final visible = _visibleSeries
        .where((series) => series.points.length >= 2)
        .toList();
    if (visible.isEmpty) return null;

    final firstDate = visible
        .map((series) => series.points.first.date)
        .reduce((earlier, later) => earlier.isBefore(later) ? earlier : later);
    final lastDate = visible
        .map((series) => series.points.last.date)
        .reduce((earlier, later) => earlier.isAfter(later) ? earlier : later);

    final chartWidth = constraints.maxWidth -
        CategoryTrendPainter.leftPadding -
        CategoryTrendPainter.rightPadding;
    if (chartWidth <= 0) return lastDate;

    final chartX = (position.dx - CategoryTrendPainter.leftPadding).clamp(
      0.0,
      chartWidth,
    );
    final dateRangeSeconds =
        lastDate.difference(firstDate).inSeconds.toDouble();
    if (dateRangeSeconds <= 0) return lastDate;

    return firstDate.add(
      Duration(seconds: ((chartX / chartWidth) * dateRangeSeconds).round()),
    );
  }

  CategoryTrendPoint? _nearestPoint(
    List<CategoryTrendPoint> points,
    DateTime hoverDate,
  ) {
    if (points.isEmpty) return null;
    return points.reduce(
      (nearestPoint, point) =>
          point.date.difference(hoverDate).inSeconds.abs() <
                  nearestPoint.date.difference(hoverDate).inSeconds.abs()
              ? point
              : nearestPoint,
    );
  }
}

class _DottedLegendSwatchPainter extends CustomPainter {
  _DottedLegendSwatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 3.0;
    const gap = 2.0;
    final y = size.height / 2;
    var x = 0.0;
    var drawDash = true;
    while (x < size.width) {
      final next = (x + (drawDash ? dash : gap)).clamp(0.0, size.width);
      if (drawDash) {
        canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      }
      x = next;
      drawDash = !drawDash;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLegendSwatchPainter oldDelegate) =>
      color != oldDelegate.color;
}
