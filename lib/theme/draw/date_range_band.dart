import 'dart:math' as math;

import 'package:budgets/features/trends/chart_date_layout.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/painting.dart';

/// Clipped date-range band for Trends overlays (life events, housing, job).
class DateRangeBandGeometry {
  const DateRangeBandGeometry({
    required this.leftX,
    required this.rightX,
    required this.drawLeftEdge,
    required this.drawRightEdge,
  });

  final double leftX;
  final double rightX;
  final bool drawLeftEdge;
  final bool drawRightEdge;
}

/// Vertical gradient treatments that bounce between consecutive chain eras.
enum DateRangeBandFillStyle {
  /// Stronger at the top, fading downward.
  fadeDown,

  /// Stronger at the bottom, fading upward.
  fadeUp,
}

/// Computes chart-clipped band geometry, or null when the range is empty.
DateRangeBandGeometry? dateRangeBandGeometry({
  required ChartDateLayout layout,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required bool showLeftEdge,
  required bool showRightEdge,
}) {
  final chartMin = layout.minDate.startOfDay;
  final chartMax = layout.maxDate.startOfDay;
  var bandStart = rangeStart.startOfDay;
  var bandEnd = rangeEnd.startOfDay;
  if (bandStart.isBefore(chartMin)) bandStart = chartMin;
  if (bandEnd.isAfter(chartMax)) bandEnd = chartMax;
  if (bandEnd.isBefore(bandStart)) return null;

  final leftX = layout.xForDate(bandStart);
  final rightX = layout.xForDate(bandEnd);
  return DateRangeBandGeometry(
    leftX: leftX,
    rightX: math.max(leftX + 1, rightX),
    drawLeftEdge: showLeftEdge && !rangeStart.startOfDay.isBefore(chartMin),
    drawRightEdge: showRightEdge && !rangeEnd.startOfDay.isAfter(chartMax),
  );
}

/// Label X at the visible left of a range (clamped into the chart).
double dateRangeLabelAnchorX({
  required ChartDateLayout layout,
  required DateTime rangeStart,
}) {
  final chartMin = layout.minDate.startOfDay;
  final chartMax = layout.maxDate.startOfDay;
  final visibleStart =
      rangeStart.startOfDay.isBefore(chartMin) ? chartMin : rangeStart.startOfDay;
  final clampedStart =
      visibleStart.isAfter(chartMax) ? chartMax : visibleStart;
  return layout.xForDate(clampedStart);
}

void paintDateRangeBand(
  Canvas canvas, {
  required ChartDateLayout layout,
  required DateRangeBandGeometry geometry,
  required Paint edgePaint,
  Paint? fillPaint,
  Color? fillColor,
  DateRangeBandFillStyle fillStyle = DateRangeBandFillStyle.fadeDown,
  double fillAlpha = 0.07,
  double? fillTop,
  double? fillBottom,
  double? edgeTop,
  double? edgeBottom,
}) {
  final resolvedFillTop = fillTop ?? layout.top;
  final resolvedFillBottom = fillBottom ?? layout.bottom;
  final resolvedEdgeTop = edgeTop ?? layout.top;
  final resolvedEdgeBottom = edgeBottom ?? layout.bottom;

  final fillRect = Rect.fromLTRB(
    geometry.leftX,
    resolvedFillTop,
    geometry.rightX,
    resolvedFillBottom,
  );
  if (fillPaint != null) {
    canvas.drawRect(fillRect, fillPaint);
  } else if (fillColor != null) {
    canvas.drawRect(
      fillRect,
      _bandFillPaint(
        color: fillColor,
        bandRect: fillRect,
        style: fillStyle,
        alpha: fillAlpha,
      ),
    );
  }
  if (geometry.drawLeftEdge) {
    canvas.drawLine(
      Offset(geometry.leftX, resolvedEdgeTop),
      Offset(geometry.leftX, resolvedEdgeBottom),
      edgePaint,
    );
  }
  if (geometry.drawRightEdge) {
    canvas.drawLine(
      Offset(geometry.rightX, resolvedEdgeTop),
      Offset(geometry.rightX, resolvedEdgeBottom),
      edgePaint,
    );
  }
}

Paint _bandFillPaint({
  required Color color,
  required Rect bandRect,
  required DateRangeBandFillStyle style,
  required double alpha,
}) {
  final peak = color.withValues(alpha: alpha);
  final clear = color.withValues(alpha: 0);
  // Peak hugs the accent edge; clears by ~12% so most of the band is empty.
  final edgeColors = [peak, clear, clear];
  const stops = [0.0, 0.12, 1.0];

  final gradient = switch (style) {
    DateRangeBandFillStyle.fadeDown => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: edgeColors,
        stops: stops,
      ),
    DateRangeBandFillStyle.fadeUp => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: edgeColors,
        stops: stops,
      ),
  };

  return Paint()
    ..shader = gradient.createShader(bandRect)
    ..style = PaintingStyle.fill;
}
