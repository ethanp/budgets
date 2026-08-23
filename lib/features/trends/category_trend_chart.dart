import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/domain/life_event.dart';
import 'package:spend_trends/domain/stay_chain.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/domain/trend_spend_rate.dart';
import 'package:spend_trends/features/trends/category_trend_painter.dart';
import 'package:spend_trends/features/trends/category_trend_point.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/category_trend_series_legend.dart';
import 'package:spend_trends/features/trends/chart_date_layout.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';
import 'package:spend_trends/features/trends/trend_point_contributors.dart';
import 'package:spend_trends/features/trends/trend_point_contributors_sheet.dart';
import 'package:spend_trends/features/trends/trend_value_scale.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/finance_colors.dart';

import 'dart:math' as math;

/// Labeled amount shown under a Trends chart title.
class ChartHeadlineFigure {
  const ChartHeadlineFigure({required this.label, required this.cents});

  final String label;
  final int cents;
}

/// One SimCity-style multi-line chart with a color legend.
class CategoryTrendChart extends ConsumerStatefulWidget {
  const CategoryTrendChart({
    required this.title,
    required this.seriesList,
    required this.transactions,
    required this.categories,
    required this.groups,
    this.lifeEvents = const [],
    this.housingChain,
    this.jobChain,
    this.subtitle =
        'Annual pace · tap a line for top contributors · drag to inspect · '
        'tap legend to show/hide · double-tap to solo',
    this.initiallyHiddenSeriesIds = const {},
    this.showSpendRateToggle = false,
    this.useDistributionLegend = false,
    this.valueKind = TrendValueKind.pace,
    this.enableContributors = true,
    this.headlineFigures = const [],
  });

  final String title;
  final String subtitle;
  final List<CategoryTrendSeries> seriesList;
  final List<BankTransaction> transactions;
  final List<SpendCategory> categories;
  final List<CategoryGroup> groups;
  final List<LifeEvent> lifeEvents;
  final StayChain? housingChain;
  final StayChain? jobChain;
  final Set<String> initiallyHiddenSeriesIds;

  /// When true, shows the shared yr/mo/day control (only one chart should).
  final bool showSpendRateToggle;

  /// Shared-scale min/med/avg/max/now whiskers for ranked category/group series.
  final bool useDistributionLegend;

  final TrendValueKind valueKind;

  /// Tap-to-open top contributors (disabled for level charts like net worth).
  final bool enableContributors;

  /// Optional labeled amounts under the title (e.g. current + smoothed NW).
  final List<ChartHeadlineFigure> headlineFigures;

  @override
  ConsumerState<CategoryTrendChart> createState() => _CategoryTrendChartState();
}

class _CategoryTrendChartState extends ConsumerState<CategoryTrendChart> {
  static const _tapSlop = 18.0;

  static final _headlineAmountStyle = EText.section.copyWith(fontSize: 22);

  late final Set<String> _hiddenSeriesIds = {
    ...widget.initiallyHiddenSeriesIds,
  };
  Offset? _hoverPosition;
  DateTime? _hoverDate;
  Offset? _pointerDown;
  bool _dragExceededSlop = false;

  List<CategoryTrendSeries> get _visibleSeries => widget.seriesList
      .where((series) => !_hiddenSeriesIds.contains(series.id))
      .toList();

  @override
  Widget build(BuildContext context) {
    final TrendSpendRate spendRate = ref.watch(trendSpendRateProvider);
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: ELayout.borderRadiusMd,
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: EText.section)),
              if (widget.showSpendRateToggle) _spendRateToggle(spendRate),
            ],
          ),
          if (widget.headlineFigures.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceSm),
            _headlineFigures(widget.headlineFigures),
          ],
          const SizedBox(height: ELayout.spaceXs),
          Text(widget.subtitle, style: EText.caption),
          const SizedBox(height: ELayout.spaceMd),
          _chartArea(),
          const SizedBox(height: ELayout.spaceSm),
          _inspectCaption(spendRate),
          const SizedBox(height: ELayout.spaceMd),
          CategoryTrendSeriesLegend(
            seriesList: widget.seriesList,
            hiddenSeriesIds: _hiddenSeriesIds,
            spendRate: spendRate,
            valueKind: widget.valueKind,
            useDistributionLegend: widget.useDistributionLegend,
            onSeriesToggled: _toggleSeries,
            onSeriesSoloed: _soloSeries,
          ),
        ],
      ),
    );
  }

  Widget _headlineFigures(List<ChartHeadlineFigure> figures) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          var figureIndex = 0;
          figureIndex < figures.length;
          figureIndex++
        ) ...[
          if (figureIndex > 0) const SizedBox(width: ELayout.spaceXl),
          Expanded(child: _headlineFigure(figures[figureIndex])),
        ],
      ],
    );
  }

  Widget _headlineFigure(ChartHeadlineFigure figure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(figure.label, style: EText.caption),
        const SizedBox(height: ELayout.spaceXs),
        Text(
          formatCents(figure.cents),
          style: figure.cents < 0
              ? _headlineAmountStyle.copyWith(color: EColors.danger)
              : _headlineAmountStyle,
        ),
      ],
    );
  }

  Widget _spendRateToggle(TrendSpendRate spendRate) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final rate in TrendSpendRate.values) ...[
          if (rate != TrendSpendRate.values.first)
            const SizedBox(width: ELayout.spaceXs),
          _settingsChip(
            label: rate.toggleLabel,
            isSelected: spendRate == rate,
            onActivated: () =>
                ref.read(trendSpendRateProvider.notifier).setRate(rate),
          ),
        ],
      ],
    );
  }

  Widget _settingsChip({
    required String label,
    required bool isSelected,
    required VoidCallback onActivated,
  }) {
    return GestureDetector(
      onTap: onActivated,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceSm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? FinanceColors.accentPrimary.withValues(alpha: 0.25)
              : EColors.surface,
          borderRadius: ELayout.borderRadiusSm,
          border: Border.all(
            color: isSelected ? FinanceColors.accentPrimary : EColors.border,
          ),
        ),
        child: Text(
          label,
          style: EText.caption.copyWith(
            color: isSelected ? FinanceColors.accentPrimary : EColors.textMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _formatSeriesCents(int cents, TrendSpendRate spendRate) {
    if (widget.valueKind == TrendValueKind.level) {
      return formatCentsWholeDollars(cents);
    }
    return formatCentsWholeDollars(spendRate.displayCents(cents));
  }

  Widget _chartArea() {
    if (!_visibleSeries.any((series) => series.points.length >= 2)) {
      return SizedBox(
        height: 560,
        child: Center(child: Text('Need more history', style: EText.caption)),
      );
    }

    return SizedBox(
      height: 560,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) {
              _pointerDown = details.localPosition;
              _dragExceededSlop = false;
              _updateHover(details.localPosition, constraints);
            },
            onTapUp: (details) {
              if (_dragExceededSlop || !widget.enableContributors) return;
              _openContributorsAt(details.localPosition, constraints);
            },
            onPanUpdate: (details) {
              final pointerDown = _pointerDown;
              if (pointerDown != null &&
                  (details.localPosition - pointerDown).distance > _tapSlop) {
                _dragExceededSlop = true;
              }
              _updateHover(details.localPosition, constraints);
            },
            onPanEnd: (_) => _clearHover(),
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: CategoryTrendPainter(
                seriesList: _visibleSeries,
                lifeEvents: widget.lifeEvents,
                housingChain: widget.housingChain,
                jobChain: widget.jobChain,
                hoverPosition: _hoverPosition,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inspectCaption(TrendSpendRate spendRate) {
    final hoverDate = _hoverDate;
    if (hoverDate == null) {
      return Text(
        widget.enableContributors
            ? 'Drag to inspect all lines at a date · '
                  'tap a line for top contributors'
            : 'Drag to inspect at a date',
        style: EText.caption,
      );
    }

    final values = _visibleSeries
        .map((series) {
          final point = _nearestPoint(series.points, hoverDate);
          final amount = point == null
              ? '—'
              : _formatSeriesCents(point.smoothedCents.round(), spendRate);
          return '${series.name} $amount';
        })
        .join(' · ');

    final rateSuffix = widget.valueKind == TrendValueKind.level
        ? ''
        : ' (${spendRate.shortLabel.trim()})';
    return Text(
      '${DateFormat.MMMd().format(hoverDate)} · $values$rateSuffix',
      style: EText.caption,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
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

  void _openContributorsAt(Offset position, BoxConstraints constraints) {
    final tapDate = _dateForPosition(position, constraints);
    if (tapDate == null) return;

    final series = _nearestVisibleSeries(position, constraints, tapDate);
    if (series == null) return;

    final contributors = TrendPointContributors.topForSeries(
      series: series,
      tapDate: tapDate,
      transactions: widget.transactions,
      categories: widget.categories,
      groups: widget.groups,
      chartSeriesList: widget.seriesList,
    );
    if (contributors.isEmpty) return;

    final tapPoint = _nearestPoint(series.points, tapDate);
    if (tapPoint == null) return;

    TrendPointContributorsSheet.show(
      context,
      seriesName: series.name,
      tapDate: tapDate,
      contributors: contributors,
      linePaceCents: tapPoint.smoothedCents.round(),
    );
  }

  CategoryTrendSeries? _nearestVisibleSeries(
    Offset position,
    BoxConstraints constraints,
    DateTime tapDate,
  ) {
    final drawable = _visibleSeries
        .where(
          (series) =>
              series.points.length >= 2 &&
              !series.guide &&
              series.id != TrendChartCatalog.housingAffordabilitySeriesId &&
              series.id != TrendChartCatalog.fireSavingsGuideSeriesId,
        )
        .toList();
    if (drawable.isEmpty) return null;

    final layout = _chartLayout(
      Size(constraints.maxWidth, constraints.maxHeight),
      drawable,
    );
    if (position.dy < layout.top || position.dy > layout.bottom) return null;

    final scale = _chartValueScale(drawable);
    CategoryTrendSeries? nearestSeries;
    var nearestDistance = double.infinity;
    for (final series in drawable) {
      final point = _nearestPoint(series.points, tapDate);
      if (point == null) continue;
      final seriesY = scale.yForCents(point.smoothedCents, layout);
      final distance = (seriesY - position.dy).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestSeries = series;
      }
    }
    return nearestSeries;
  }

  ChartDateLayout _chartLayout(Size size, List<CategoryTrendSeries> drawable) {
    final firstDate = drawable
        .map((series) => series.points.first.date)
        .reduce((earlier, later) => earlier.isBefore(later) ? earlier : later);
    final lastDate = drawable
        .map((series) => series.points.last.date)
        .reduce((earlier, later) => earlier.isAfter(later) ? earlier : later);
    return ChartDateLayout(
      size: size,
      leftPadding: CategoryTrendPainter.leftPadding,
      rightPadding: CategoryTrendPainter.rightPadding,
      topPadding: CategoryTrendPainter.overlayStripHeight,
      bottomPadding: 24,
      minDate: firstDate,
      maxDate: lastDate,
    );
  }

  TrendValueScale _chartValueScale(List<CategoryTrendSeries> drawable) {
    var highest = 0.0;
    for (final series in drawable) {
      for (final point in series.points) {
        highest = math.max(highest, point.smoothedCents);
      }
    }
    return TrendValueScale.niceForMax(highest);
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

    final chartWidth =
        constraints.maxWidth -
        CategoryTrendPainter.leftPadding -
        CategoryTrendPainter.rightPadding;
    if (chartWidth <= 0) return lastDate;

    final chartX = (position.dx - CategoryTrendPainter.leftPadding).clamp(
      0.0,
      chartWidth,
    );
    final dateRangeSeconds = lastDate
        .difference(firstDate)
        .inSeconds
        .toDouble();
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
