import 'package:budgets/domain/life_event.dart';
import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/domain/trend_spend_rate.dart';
import 'package:budgets/features/trends/category_trend_painter.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/category_trend_series_legend.dart';
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
    this.housingChain,
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
  final StayChain? housingChain;
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

  bool get _showChainEraFills => ref.watch(showChainEraFillsProvider);

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
              if (widget.showSpendRateToggle) _chartSettingsToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.subtitle, style: AppText.caption),
          const SizedBox(height: AppSpacing.md),
          _chartArea(),
          const SizedBox(height: AppSpacing.sm),
          _inspectCaption(),
          const SizedBox(height: AppSpacing.md),
          CategoryTrendSeriesLegend(
            seriesList: widget.seriesList,
            hiddenSeriesIds: _hiddenSeriesIds,
            spendRate: _spendRate,
            useDistributionLegend: widget.useDistributionLegend,
            onToggleSeries: _toggleSeries,
            onSoloSeries: _soloSeries,
          ),
        ],
      ),
    );
  }

  Widget _chartSettingsToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _settingsChip(
          label: 'eras',
          isSelected: _showChainEraFills,
          onTap: () => ref.read(showChainEraFillsProvider.notifier).toggle(),
        ),
        const SizedBox(width: AppSpacing.sm),
        for (final rate in TrendSpendRate.values) ...[
          if (rate != TrendSpendRate.values.first)
            const SizedBox(width: AppSpacing.xs),
          _settingsChip(
            label: rate.toggleLabel,
            isSelected: _spendRate == rate,
            onTap: () =>
                ref.read(trendSpendRateProvider.notifier).setRate(rate),
          ),
        ],
      ],
    );
  }

  Widget _settingsChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
          label,
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

  Widget _chartArea() {
    if (!_visibleSeries.any((series) => series.points.length >= 2)) {
      return const SizedBox(
        height: 560,
        child: Center(
          child: Text('Need more history', style: AppText.caption),
        ),
      );
    }

    return SizedBox(
      height: 560,
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
                housingChain: widget.housingChain,
                jobChain: widget.jobChain,
                showChainEraFills: _showChainEraFills,
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
