import 'dart:math' as math;

import 'package:budgets/domain/life_event.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/chart_date_layout.dart';
import 'package:budgets/features/trends/trend_value_scale.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

class CategoryTrendPainter extends CustomPainter {
  CategoryTrendPainter({
    required this.seriesList,
    this.lifeEvents = const [],
    this.hoverPosition,
  });

  static const leftPadding = 40.0;
  static const rightPadding = 12.0;
  static const _labelOverlapPx = 14.0;
  static const _labelStackStep = 12.0;

  final List<CategoryTrendSeries> seriesList;
  final List<LifeEvent> lifeEvents;
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
    _drawLifeEventMarkers(canvas, layout);
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

  TrendValueScale _valueScale(List<CategoryTrendSeries> drawableSeries) {
    var highest = 0.0;
    for (final series in drawableSeries) {
      for (final point in series.points) {
        highest = math.max(highest, point.smoothedCents);
      }
    }
    return TrendValueScale.niceForMax(highest);
  }

  void _drawBackground(
    Canvas canvas,
    ChartDateLayout layout,
    TrendValueScale scale,
  ) {
    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.55)
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;
    for (final tickCents in scale.tickCents) {
      if (tickCents <= 0) continue;
      final lineY = scale.yForCents(tickCents, layout);
      _drawDashedHorizontal(
        canvas,
        start: Offset(layout.left, lineY),
        endX: layout.right,
        paint: gridPaint,
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
    TrendValueScale scale,
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
    TrendValueScale scale,
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

  void _drawDashedHorizontal(
    Canvas canvas, {
    required Offset start,
    required double endX,
    required Paint paint,
    double dashLength = 4,
    double gapLength = 3,
  }) {
    var x = start.dx;
    var drawingDash = true;
    while (x < endX) {
      final next = math.min(x + (drawingDash ? dashLength : gapLength), endX);
      if (drawingDash) {
        canvas.drawLine(Offset(x, start.dy), Offset(next, start.dy), paint);
      }
      x = next;
      drawingDash = !drawingDash;
    }
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

  void _drawLifeEventMarkers(Canvas canvas, ChartDateLayout layout) {
    final markersInRange = [
      for (final lifeEvent in lifeEvents)
        if (!lifeEvent.occurredOn.isBefore(layout.minDate.startOfDay) &&
            !lifeEvent.occurredOn.isAfter(layout.maxDate.startOfDay))
          lifeEvent,
    ]..sort(
        (firstEvent, secondEvent) =>
            firstEvent.occurredOn.compareTo(secondEvent.occurredOn),
      );
    if (markersInRange.isEmpty) return;

    final linePaint = Paint()
      ..color = AppColors.accentSecondary.withValues(alpha: 0.55)
      ..strokeWidth = 1.25;
    final stackLaneByIndex = _labelStackLanes(markersInRange, layout);

    for (var markerIndex = 0;
        markerIndex < markersInRange.length;
        markerIndex++) {
      final lifeEvent = markersInRange[markerIndex];
      final markerX = layout.xForDate(lifeEvent.occurredOn.startOfDay);
      _drawDashedVertical(
        canvas,
        Offset(markerX, layout.top),
        Offset(markerX, layout.bottom),
        linePaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: lifeEvent.title,
          style: const TextStyle(
            color: AppColors.accentSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 96);

      final labelX = (markerX + 3).clamp(
        layout.left,
        layout.right - textPainter.width,
      );
      final labelY =
          layout.top + 2 + stackLaneByIndex[markerIndex] * _labelStackStep;
      textPainter.paint(canvas, Offset(labelX, labelY));
    }
  }

  List<int> _labelStackLanes(
    List<LifeEvent> markersInRange,
    ChartDateLayout layout,
  ) {
    final lanes = List<int>.filled(markersInRange.length, 0);
    final lastXByLane = <int, double>{};
    for (var markerIndex = 0;
        markerIndex < markersInRange.length;
        markerIndex++) {
      final markerX =
          layout.xForDate(markersInRange[markerIndex].occurredOn.startOfDay);
      var lane = 0;
      while (true) {
        final previousX = lastXByLane[lane];
        if (previousX == null || markerX - previousX >= _labelOverlapPx) {
          lanes[markerIndex] = lane;
          lastXByLane[lane] = markerX;
          break;
        }
        lane++;
      }
    }
    return lanes;
  }

  void _drawDashedVertical(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashLength = 4.0;
    const gapLength = 3.0;
    final height = end.dy - start.dy;
    if (height <= 0) return;
    var drawn = 0.0;
    var drawingDash = true;
    while (drawn < height) {
      final step = drawingDash ? dashLength : gapLength;
      final next = math.min(drawn + step, height);
      if (drawingDash) {
        canvas.drawLine(
          Offset(start.dx, start.dy + drawn),
          Offset(start.dx, start.dy + next),
          paint,
        );
      }
      drawn = next;
      drawingDash = !drawingDash;
    }
  }

  void _drawHoverMarker(
    Canvas canvas,
    ChartDateLayout layout,
    TrendValueScale scale,
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
    TrendValueScale scale,
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
      lifeEvents != oldDelegate.lifeEvents ||
      hoverPosition != oldDelegate.hoverPosition;
}
