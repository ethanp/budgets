import 'package:budgets/features/trends/category_trend_painter.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// One SimCity-style multi-line chart with a color legend.
class CategoryTrendChart extends StatefulWidget {
  const CategoryTrendChart({
    super.key,
    required this.title,
    required this.seriesList,
    this.subtitle =
        'Smoothed trailing 30-day · tap legend to show/hide · double-tap to solo',
    this.initiallyHiddenSeriesIds = const {},
  });

  final String title;
  final String subtitle;
  final List<CategoryTrendSeries> seriesList;
  final Set<String> initiallyHiddenSeriesIds;

  @override
  State<CategoryTrendChart> createState() => _CategoryTrendChartState();
}

class _CategoryTrendChartState extends State<CategoryTrendChart> {
  late final Set<String> _hiddenSeriesIds = {
    ...widget.initiallyHiddenSeriesIds,
  };
  Offset? _hoverPosition;
  DateTime? _hoverDate;

  List<CategoryTrendSeries> get _visibleSeries => widget.seriesList
      .where((series) => !_hiddenSeriesIds.contains(series.id))
      .toList();

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
          Text(widget.title, style: AppText.body.large.semibold),
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
          : formatCentsCompact(point.smoothedCents.round());
      return '${series.name} $amount';
    }).join(' · ');

    return Text(
      '${DateFormat.MMMd().format(hoverDate)} · $values',
      style: AppText.caption,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final series in widget.seriesList) _legendChip(series),
      ],
    );
  }

  Widget _legendChip(CategoryTrendSeries series) {
    final isHidden = _hiddenSeriesIds.contains(series.id);
    return GestureDetector(
      onTap: () => _toggleSeries(series.id),
      onDoubleTap: () => _soloSeries(series.id),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendSwatch(series, isHidden),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${series.name} · '
            '${formatCentsCompact(series.latestSmoothedCents.round())}',
            style: isHidden
                ? AppText.body.small.copyWith(color: AppColors.textColor4)
                : AppText.body.small,
          ),
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
