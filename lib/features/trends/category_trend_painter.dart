import 'dart:math' as math;

import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/chart_date_layout.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:flutter/cupertino.dart';

class CategoryTrendPainter extends CustomPainter {
  CategoryTrendPainter({
    required this.seriesList,
    this.hoverPosition,
  });

  static const leftPadding = 40.0;
  static const rightPadding = 12.0;

  final List<CategoryTrendSeries> seriesList;
  final Offset? hoverPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final drawableSeries =
        seriesList.where((series) => series.points.length >= 2).toList();
    if (drawableSeries.isEmpty) return;

    final layout = _layout(size, drawableSeries);
    final scale = _valueScale(drawableSeries);
    _drawBackground(canvas, layout, scale);
    for (final series in drawableSeries) {
      if (series.percentileAreaFill) {
        _drawPercentileArea(canvas, layout, scale, series);
      }
    }
    for (final series in drawableSeries) {
      _drawSeriesLine(canvas, layout, scale, series);
    }
    _drawHoverMarker(canvas, layout, scale, drawableSeries);
    _drawAxisLabels(canvas, layout, scale);
  }

  ChartDateLayout _layout(Size size, List<CategoryTrendSeries> drawableSeries) {
    final firstDate = drawableSeries
        .map((series) => series.points.first.date)
        .reduce((earlier, later) => earlier.isBefore(later) ? earlier : later);
    final lastDate = drawableSeries
        .map((series) => series.points.last.date)
        .reduce((earlier, later) => earlier.isAfter(later) ? earlier : later);
    return ChartDateLayout(
      size: size,
      leftPadding: leftPadding,
      rightPadding: rightPadding,
      topPadding: 8,
      bottomPadding: 24,
      minDate: firstDate,
      maxDate: lastDate,
    );
  }

  _TrendValueScale _valueScale(List<CategoryTrendSeries> drawableSeries) {
    var highest = 0.0;
    for (final series in drawableSeries) {
      for (final point in series.points) {
        highest = math.max(highest, point.smoothedCents);
      }
    }
    return _TrendValueScale.niceForMax(highest);
  }

  void _drawBackground(
    Canvas canvas,
    ChartDateLayout layout,
    _TrendValueScale scale,
  ) {
    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (final tickCents in scale.tickCents) {
      if (tickCents <= 0) continue;
      final lineY = scale.yForCents(tickCents, layout);
      canvas.drawLine(
        Offset(layout.left, lineY),
        Offset(layout.right, lineY),
        gridPaint,
      );
    }
    layout.drawAxes(canvas);
    layout.drawYearBoundaries(canvas);
    layout.drawDateLabels(canvas, labelColor: AppColors.textColor4);
  }

  /// Area under the curve: vertical fade to the baseline, with opacity set by
  /// each x-column's percentile rank within that series' smoothed history.
  ///
  /// Drawn per pixel column (not per data point) so multi-year daily series
  /// still fill — consecutive days are often sub-pixel on the x-axis.
  void _drawPercentileArea(
    Canvas canvas,
    ChartDateLayout layout,
    _TrendValueScale scale,
    CategoryTrendSeries series,
  ) {
    final points = series.points;
    if (points.length < 2) return;

    final sortedValues = points.map((point) => point.smoothedCents).toList()
      ..sort();
    final baselineY = scale.yForCents(0, layout);
    const columnWidth = 1.0;

    for (var columnX = layout.left;
        columnX < layout.right;
        columnX += columnWidth) {
      final sampleDate = layout.dateForX(columnX + columnWidth / 2);
      final sampleCents = _smoothedCentsAt(points, sampleDate);
      if (sampleCents <= 0) continue;

      final topY = scale.yForCents(sampleCents, layout);
      if (baselineY - topY < 1) continue;

      final percentile = _percentileRank(sortedValues, sampleCents);
      final peakAlpha = 0.14 + 0.42 * percentile;
      final columnRect = Rect.fromLTRB(
        columnX,
        topY,
        columnX + columnWidth,
        baselineY,
      );
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            series.lineColor.withValues(alpha: peakAlpha),
            series.lineColor.withValues(alpha: 0),
          ],
        ).createShader(columnRect);
      canvas.drawRect(columnRect, fillPaint);
    }
  }

  double _smoothedCentsAt(
    List<CategoryTrendPoint> points,
    DateTime sampleDate,
  ) {
    if (sampleDate.isBefore(points.first.date)) {
      return points.first.smoothedCents;
    }
    if (sampleDate.isAfter(points.last.date)) {
      return points.last.smoothedCents;
    }

    for (var pointIndex = 0; pointIndex < points.length - 1; pointIndex++) {
      final leftPoint = points[pointIndex];
      final rightPoint = points[pointIndex + 1];
      if (sampleDate.isAfter(rightPoint.date)) continue;

      final spanSeconds =
          rightPoint.date.difference(leftPoint.date).inSeconds.toDouble();
      if (spanSeconds <= 0) return leftPoint.smoothedCents;
      final t = sampleDate.difference(leftPoint.date).inSeconds / spanSeconds;
      return leftPoint.smoothedCents +
          (rightPoint.smoothedCents - leftPoint.smoothedCents) * t.clamp(0.0, 1.0);
    }
    return points.last.smoothedCents;
  }

  /// Empirical percentile rank in [0, 1] for [value] among [sortedValues].
  double _percentileRank(List<double> sortedValues, double value) {
    if (sortedValues.isEmpty) return 0;
    if (sortedValues.length == 1) return 0.5;

    var countBelow = 0;
    var countEqual = 0;
    for (final sample in sortedValues) {
      if (sample < value) {
        countBelow++;
      } else if (sample == value) {
        countEqual++;
      } else {
        break;
      }
    }
    return ((countBelow + 0.5 * countEqual) / sortedValues.length)
        .clamp(0.0, 1.0);
  }

  void _drawSeriesLine(
    Canvas canvas,
    ChartDateLayout layout,
    _TrendValueScale scale,
    CategoryTrendSeries series,
  ) {
    final offsets = <Offset>[
      for (final point in series.points)
        Offset(
          layout.xForDate(point.date),
          scale.yForCents(point.smoothedCents, layout),
        ),
    ];
    if (offsets.length < 2) return;

    final linePaint = Paint()
      ..color = series.lineColor
      ..strokeWidth = series.dotted ? 2.5 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (series.dotted) {
      _drawDottedPolyline(canvas, offsets, linePaint);
      return;
    }

    final seriesPath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var offsetIndex = 1; offsetIndex < offsets.length; offsetIndex++) {
      seriesPath.lineTo(offsets[offsetIndex].dx, offsets[offsetIndex].dy);
    }
    canvas.drawPath(seriesPath, linePaint);
  }

  void _drawDottedPolyline(
    Canvas canvas,
    List<Offset> offsets,
    Paint linePaint,
  ) {
    const dashLength = 5.0;
    const gapLength = 4.0;
    for (var segmentIndex = 0;
        segmentIndex < offsets.length - 1;
        segmentIndex++) {
      final start = offsets[segmentIndex];
      final end = offsets[segmentIndex + 1];
      final segment = end - start;
      final segmentLength = segment.distance;
      if (segmentLength <= 0) continue;
      final direction = segment / segmentLength;
      var drawn = 0.0;
      var drawingDash = true;
      while (drawn < segmentLength) {
        final step = drawingDash ? dashLength : gapLength;
        final next = math.min(drawn + step, segmentLength);
        if (drawingDash) {
          canvas.drawLine(
            start + direction * drawn,
            start + direction * next,
            linePaint,
          );
        }
        drawn = next;
        drawingDash = !drawingDash;
      }
    }
  }

  void _drawHoverMarker(
    Canvas canvas,
    ChartDateLayout layout,
    _TrendValueScale scale,
    List<CategoryTrendSeries> drawableSeries,
  ) {
    final position = hoverPosition;
    if (position == null) return;

    final hoverDate = layout.dateForX(position.dx);
    final hoveredX = layout.xForDate(hoverDate);
    final markerPaint = Paint()
      ..color = AppColors.textColor3.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(hoveredX, layout.top),
      Offset(hoveredX, layout.bottom),
      markerPaint,
    );

    for (final series in drawableSeries) {
      final point = _nearestPoint(series.points, hoverDate);
      if (point == null) continue;
      final ringPaint = Paint()
        ..color = series.lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(
        Offset(hoveredX, scale.yForCents(point.smoothedCents, layout)),
        4,
        ringPaint,
      );
    }
  }

  void _drawAxisLabels(
    Canvas canvas,
    ChartDateLayout layout,
    _TrendValueScale scale,
  ) {
    for (final tickCents in scale.tickCents) {
      final label = formatAxisCents(tickCents);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: AppColors.textColor4, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelY = scale.yForCents(tickCents, layout) - textPainter.height / 2;
      textPainter.paint(
        canvas,
        Offset(
          layout.left - textPainter.width - 4,
          labelY.clamp(layout.top - 2, layout.bottom - textPainter.height),
        ),
      );
    }
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

  @override
  bool shouldRepaint(covariant CategoryTrendPainter oldDelegate) =>
      seriesList != oldDelegate.seriesList ||
      hoverPosition != oldDelegate.hoverPosition;
}

/// Y scale snapped to human-readable tick steps for the data max.
class _TrendValueScale {
  const _TrendValueScale({
    required this.maxCents,
    required this.tickCents,
  });

  final double maxCents;
  final List<double> tickCents;

  factory _TrendValueScale.niceForMax(double dataMaxCents) {
    const targetTickCount = 4;
    if (dataMaxCents <= 0) {
      return const _TrendValueScale(
        maxCents: 10000,
        tickCents: [0, 2500, 5000, 7500, 10000],
      );
    }

    final roughStep = dataMaxCents / targetTickCount;
    final stepCents = _niceNumber(roughStep, round: true);
    final niceMaxCents = (dataMaxCents / stepCents).ceil() * stepCents;
    final tickCents = <double>[];
    for (var tick = 0.0; tick <= niceMaxCents + stepCents * 0.001; tick += stepCents) {
      tickCents.add(tick);
    }
    return _TrendValueScale(maxCents: niceMaxCents, tickCents: tickCents);
  }

  double yForCents(double cents, ChartDateLayout layout) {
    final valueFraction = (cents / maxCents).clamp(0.0, 1.0);
    return layout.bottom - valueFraction * layout.height;
  }

  /// Classic "nice number" step (1 / 2 / 5 × 10^n).
  static double _niceNumber(double value, {required bool round}) {
    if (value <= 0) return 100;
    final exponent = (math.log(value) / math.ln10).floor();
    final fraction = value / math.pow(10, exponent);
    late final double niceFraction;
    if (round) {
      if (fraction < 1.5) {
        niceFraction = 1;
      } else if (fraction < 3) {
        niceFraction = 2;
      } else if (fraction < 7) {
        niceFraction = 5;
      } else {
        niceFraction = 10;
      }
    } else if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
    return niceFraction * math.pow(10, exponent);
  }
}
