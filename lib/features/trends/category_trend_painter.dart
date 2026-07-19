import 'dart:math' as math;

import 'package:budgets/domain/life_event.dart';
import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/chart_date_layout.dart';
import 'package:budgets/features/trends/trend_value_scale.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/theme/draw/date_range_band.dart';
import 'package:budgets/util/money_format.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

class CategoryTrendPainter extends CustomPainter {
  CategoryTrendPainter({
    required this.seriesList,
    this.lifeEvents = const [],
    this.housingChain,
    this.jobChain,
    this.showChainEraFills = true,
    this.hoverPosition,
  });

  static const leftPadding = 48.0;
  static const rightPadding = 12.0;

  /// date / housing / job / life-event rows above the plot.
  /// Tall enough for a few within-lane label stacks when stays are close.
  static const overlayLaneCount = 4;
  static const overlayLaneHeight = 34.0;
  static const overlayStripHeight = overlayLaneCount * overlayLaneHeight;

  static const dateLane = 0;
  static const housingLane = 1;
  static const jobLane = 2;
  static const lifeEventLane = 3;

  final List<CategoryTrendSeries> seriesList;
  final List<LifeEvent> lifeEvents;
  final StayChain? housingChain;
  final StayChain? jobChain;
  final bool showChainEraFills;
  final Offset? hoverPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final drawableSeries =
        seriesList.where((series) => series.points.length >= 2).toList();
    if (drawableSeries.isEmpty) return;

    _CategoryTrendPaintSession(
      canvas: canvas,
      layout: _layout(size, drawableSeries),
      scale: _valueScale(drawableSeries),
      drawableSeries: drawableSeries,
      lifeEvents: lifeEvents,
      housingChain: housingChain,
      jobChain: jobChain,
      showChainEraFills: showChainEraFills,
      hoverPosition: hoverPosition,
    ).paint();
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
      topPadding: overlayStripHeight,
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

  @override
  bool shouldRepaint(covariant CategoryTrendPainter oldDelegate) =>
      seriesList != oldDelegate.seriesList ||
      lifeEvents != oldDelegate.lifeEvents ||
      housingChain != oldDelegate.housingChain ||
      jobChain != oldDelegate.jobChain ||
      showChainEraFills != oldDelegate.showChainEraFills ||
      hoverPosition != oldDelegate.hoverPosition;
}

/// One `paint()` frame: canvas + layout + scale, with draw helpers as methods.
class _CategoryTrendPaintSession {
  _CategoryTrendPaintSession({
    required this.canvas,
    required this.layout,
    required this.scale,
    required this.drawableSeries,
    required this.lifeEvents,
    required this.housingChain,
    required this.jobChain,
    required this.showChainEraFills,
    required this.hoverPosition,
  });

  static const _labelMaxWidth = 96.0;
  static const _labelStackStep = 11.0;
  static const _labelStackGapPx = 6.0;
  static const _eraEdgeAlpha = 0.4;
  static const _eraEdgeStroke = 1.0;

  final Canvas canvas;
  final ChartDateLayout layout;
  final TrendValueScale scale;
  final List<CategoryTrendSeries> drawableSeries;
  final List<LifeEvent> lifeEvents;
  final StayChain? housingChain;
  final StayChain? jobChain;
  final bool showChainEraFills;
  final Offset? hoverPosition;

  double _laneTop(int laneIndex) =>
      laneIndex * CategoryTrendPainter.overlayLaneHeight;

  double _laneBottom(int laneIndex) =>
      _laneTop(laneIndex) + CategoryTrendPainter.overlayLaneHeight;

  double _laneLabelY(int laneIndex) => _laneTop(laneIndex) + 2;

  int _laneForKind(LifeChainKind kind) => switch (kind) {
        LifeChainKind.housing => CategoryTrendPainter.housingLane,
        LifeChainKind.job => CategoryTrendPainter.jobLane,
      };

  void paint() {
    _drawBackground();
    for (final series in drawableSeries) {
      if (series.percentileAreaFill) {
        _drawPercentileArea(series);
      }
    }
    for (final series in drawableSeries) {
      _drawSeriesLine(series);
    }

    final chartMin = layout.minDate.startOfDay;
    final chartMax = layout.maxDate.startOfDay;
    final housingSegments = _visibleStaySegments(
      housingChain,
      chartMin: chartMin,
      chartMax: chartMax,
    );
    final jobSegments = _visibleStaySegments(
      jobChain,
      chartMin: chartMin,
      chartMax: chartMax,
    );
    final lifeEventsInRange = _visibleLifeEvents(
      chartMin: chartMin,
      chartMax: chartMax,
    );

    _drawStayChainBands(
      kind: LifeChainKind.housing,
      chain: housingChain,
      segments: housingSegments,
    );
    _drawStayChainBands(
      kind: LifeChainKind.job,
      chain: jobChain,
      segments: jobSegments,
    );
    _drawLifeEventMarkers(lifeEventsInRange);
    _drawHoverMarker();
    _drawAxisLabels();
  }

  void _drawBackground() {
    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.55)
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;
    for (final tickCents in scale.tickCents) {
      if (tickCents <= 0) continue;
      final lineY = scale.yForCents(tickCents, layout);
      _drawDashedHorizontal(
        start: Offset(layout.left, lineY),
        endX: layout.right,
        paint: gridPaint,
      );
    }
    layout.drawAxes(canvas);
    layout.drawYearBoundaries(
      canvas,
      yearLabelY: _laneLabelY(CategoryTrendPainter.dateLane),
      labelStyle: AppText.chartAxis,
    );
    layout.drawDateLabels(canvas, labelStyle: AppText.chartAxis);
  }

  /// Area under the curve: vertical fade to the baseline, with opacity set by
  /// each x-column's percentile rank within that series' smoothed history.
  ///
  /// Drawn per pixel column (not per data point) so multi-year daily series
  /// still fill — consecutive days are often sub-pixel on the x-axis.
  void _drawPercentileArea(CategoryTrendSeries series) {
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

  void _drawSeriesLine(CategoryTrendSeries series) {
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
      ..strokeWidth = series.guide
          ? 1.25
          : series.dotted
              ? 2.5
              : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = series.guide ? StrokeCap.butt : StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (series.guide) {
      _drawDottedPolyline(
        offsets,
        linePaint,
        dashLength: 8,
        gapLength: 10,
      );
      return;
    }
    if (series.dotted) {
      _drawDottedPolyline(offsets, linePaint);
      return;
    }

    final seriesPath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var offsetIndex = 1; offsetIndex < offsets.length; offsetIndex++) {
      seriesPath.lineTo(offsets[offsetIndex].dx, offsets[offsetIndex].dy);
    }
    canvas.drawPath(seriesPath, linePaint);
  }

  void _drawDashedHorizontal({
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
    List<Offset> offsets,
    Paint linePaint, {
    double dashLength = 5,
    double gapLength = 4,
  }) {
    // Carry dash phase across segments — daily points are often sub-pixel, so
    // resetting per segment paints a solid line.
    var drawingDash = true;
    var phaseRemaining = dashLength;
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
      while (drawn < segmentLength) {
        final step = math.min(phaseRemaining, segmentLength - drawn);
        if (drawingDash && step > 0.25) {
          canvas.drawLine(
            start + direction * drawn,
            start + direction * (drawn + step),
            linePaint,
          );
        }
        drawn += step;
        phaseRemaining -= step;
        if (phaseRemaining <= 0) {
          drawingDash = !drawingDash;
          phaseRemaining = drawingDash ? dashLength : gapLength;
        }
      }
    }
  }

  List<ChainStaySegment> _visibleStaySegments(
    StayChain? chain, {
    required DateTime chartMin,
    required DateTime chartMax,
  }) {
    if (chain == null || chain.isEmpty) return const [];
    return [
      for (final segment in chain.segments)
        if (segment.intersectsChart(
          chartMinDate: chartMin,
          chartMaxDate: chartMax,
        ))
          segment,
    ];
  }

  List<LifeEvent> _visibleLifeEvents({
    required DateTime chartMin,
    required DateTime chartMax,
  }) {
    return [
      for (final lifeEvent in lifeEvents)
        if (lifeEvent.intersectsChart(
          chartMinDate: chartMin,
          chartMaxDate: chartMax,
        ))
          lifeEvent,
    ]..sort(
        (firstEvent, secondEvent) =>
            firstEvent.startedOn.compareTo(secondEvent.startedOn),
      );
  }

  void _drawStayChainBands({
    required LifeChainKind kind,
    required StayChain? chain,
    required List<ChainStaySegment> segments,
  }) {
    if (segments.isEmpty) return;
    final laneIndex = _laneForKind(kind);
    final fillTop = _laneTop(laneIndex);
    final fillBottom = _laneBottom(laneIndex);
    final baseLabelY = _laneLabelY(laneIndex);
    final chartMax = layout.maxDate.startOfDay;
    final chainSegments = chain?.segments ?? const <ChainStaySegment>[];
    final eraIndexByStayId = {
      for (var eraIndex = 0; eraIndex < chainSegments.length; eraIndex++)
        chainSegments[eraIndex].stay.id: eraIndex,
    };

    final labelLeftXs = <double>[];
    final labelWidths = <double>[];
    final textPainters = <TextPainter>[];
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final eraIndex = eraIndexByStayId[segment.stay.id] ?? index;
      final eraAccent = kind.trendEraAccent(eraIndex);
      final textPainter = TextPainter(
        text: _stayChainLabelSpan(
          kind: kind,
          label: segment.stay.label,
          color: eraAccent,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: _labelMaxWidth);
      final labelAnchorX = dateRangeLabelAnchorX(
        layout: layout,
        rangeStart: segment.rangeStart,
      );
      final labelX = (labelAnchorX + 3).clamp(
        layout.left,
        layout.right - textPainter.width,
      );
      labelLeftXs.add(labelX);
      labelWidths.add(textPainter.width);
      textPainters.add(textPainter);
    }
    final stackRows = _withinLaneStackRows(
      labelLeftXs: labelLeftXs,
      labelWidths: labelWidths,
    );

    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final eraIndex = eraIndexByStayId[segment.stay.id] ?? index;
      final eraAccent = kind.trendEraAccent(eraIndex);
      final fillStyle = eraIndex.isEven
          ? DateRangeBandFillStyle.solid
          : DateRangeBandFillStyle.hatch;
      final edgePaint = Paint()
        ..color = eraAccent.withValues(alpha: _eraEdgeAlpha)
        ..strokeWidth = _eraEdgeStroke;

      final geometry = dateRangeBandGeometry(
        layout: layout,
        rangeStart: segment.rangeStart,
        rangeEnd: segment.effectiveEndOn(chartMax),
        showLeftEdge: true,
        showRightEdge: segment.rangeEnd != null,
      );
      if (geometry != null) {
        paintDateRangeBand(
          canvas,
          layout: layout,
          geometry: geometry,
          edgePaint: edgePaint,
          fillColor: showChainEraFills ? eraAccent : null,
          fillStyle: fillStyle,
          fillAlpha: 0.12,
          fillTop: fillTop,
          fillBottom: fillBottom,
          edgeTop: layout.top,
          edgeBottom: layout.bottom,
        );
      }

      final labelY = baseLabelY + stackRows[index] * _labelStackStep;
      textPainters[index].paint(canvas, Offset(labelLeftXs[index], labelY));
    }
  }

  /// Greedy vertical rows inside one overlay lane when label boxes collide on X.
  List<int> _withinLaneStackRows({
    required List<double> labelLeftXs,
    required List<double> labelWidths,
  }) {
    final order = [for (var index = 0; index < labelLeftXs.length; index++) index]
      ..sort(
        (left, right) => labelLeftXs[left].compareTo(labelLeftXs[right]),
      );
    final stackRows = List<int>.filled(labelLeftXs.length, 0);
    final lastRightByRow = <int, double>{};
    for (final index in order) {
      final labelLeft = labelLeftXs[index];
      final labelRight = labelLeft + labelWidths[index];
      var row = 0;
      while (true) {
        final previousRight = lastRightByRow[row];
        if (previousRight == null ||
            labelLeft >= previousRight + _labelStackGapPx) {
          stackRows[index] = row;
          lastRightByRow[row] = labelRight;
          break;
        }
        row++;
      }
    }
    return stackRows;
  }

  TextSpan _stayChainLabelSpan({
    required LifeChainKind kind,
    required String label,
    required Color color,
  }) {
    final labelStyle = TextStyle(
      color: color,
      fontSize: 9,
      fontWeight: FontWeight.w600,
      height: 1,
    );
    if (kind != LifeChainKind.housing) {
      return TextSpan(text: label, style: labelStyle);
    }
    const houseIcon = CupertinoIcons.house_fill;
    return TextSpan(
      children: [
        TextSpan(
          text: String.fromCharCode(houseIcon.codePoint),
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontFamily: houseIcon.fontFamily,
            package: houseIcon.fontPackage,
            height: 1,
          ),
        ),
        TextSpan(text: ' $label', style: labelStyle),
      ],
    );
  }

  void _drawLifeEventMarkers(List<LifeEvent> markersInRange) {
    if (markersInRange.isEmpty) return;
    final chartMax = layout.maxDate.startOfDay;
    final fillTop = _laneTop(CategoryTrendPainter.lifeEventLane);
    final fillBottom = _laneBottom(CategoryTrendPainter.lifeEventLane);
    final baseLabelY = _laneLabelY(CategoryTrendPainter.lifeEventLane);

    final bandFillPaint = Paint()
      ..color = AppColors.accentSecondary.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final bandEdgePaint = Paint()
      ..color = AppColors.accentSecondary.withValues(alpha: _eraEdgeAlpha)
      ..strokeWidth = _eraEdgeStroke;
    final linePaint = Paint()
      ..color = AppColors.accentSecondary.withValues(alpha: _eraEdgeAlpha)
      ..strokeWidth = _eraEdgeStroke;

    final labelLeftXs = <double>[];
    final labelWidths = <double>[];
    final textPainters = <TextPainter>[];
    for (final lifeEvent in markersInRange) {
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
      )..layout(maxWidth: _labelMaxWidth);
      final labelAnchorX = dateRangeLabelAnchorX(
        layout: layout,
        rangeStart: lifeEvent.startedOn,
      );
      final labelX = (labelAnchorX + 3).clamp(
        layout.left,
        layout.right - textPainter.width,
      );
      labelLeftXs.add(labelX);
      labelWidths.add(textPainter.width);
      textPainters.add(textPainter);
    }
    final stackRows = _withinLaneStackRows(
      labelLeftXs: labelLeftXs,
      labelWidths: labelWidths,
    );

    for (var markerIndex = 0;
        markerIndex < markersInRange.length;
        markerIndex++) {
      final lifeEvent = markersInRange[markerIndex];
      final labelAnchorX = dateRangeLabelAnchorX(
        layout: layout,
        rangeStart: lifeEvent.startedOn,
      );

      if (lifeEvent.isPoint) {
        _drawDashedVertical(
          Offset(labelAnchorX, layout.top),
          Offset(labelAnchorX, layout.bottom),
          linePaint,
        );
      } else {
        final geometry = dateRangeBandGeometry(
          layout: layout,
          rangeStart: lifeEvent.startedOn,
          rangeEnd: lifeEvent.effectiveEndOn(chartMax),
          showLeftEdge: true,
          showRightEdge: lifeEvent.isClosedRange,
        );
        if (geometry != null) {
          paintDateRangeBand(
            canvas,
            layout: layout,
            geometry: geometry,
            fillPaint: bandFillPaint,
            edgePaint: bandEdgePaint,
            fillTop: fillTop,
            fillBottom: fillBottom,
            edgeTop: layout.top,
            edgeBottom: layout.bottom,
          );
        }
      }

      final labelY = baseLabelY + stackRows[markerIndex] * _labelStackStep;
      textPainters[markerIndex].paint(
        canvas,
        Offset(labelLeftXs[markerIndex], labelY),
      );
    }
  }

  void _drawDashedVertical(Offset start, Offset end, Paint paint) {
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

  void _drawHoverMarker() {
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

  void _drawAxisLabels() {
    final axisStyle = AppText.chartAxis;
    for (final tickCents in scale.tickCents) {
      final label = formatAxisCents(tickCents);
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: axisStyle),
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
}
