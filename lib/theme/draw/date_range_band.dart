import 'dart:math' as math;

import 'package:budgets/features/trends/chart_date_layout.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/painting.dart';

/// Clipped date-range band for Trends overlays (life events, homebase, job).
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

/// Contrasting fill treatments for consecutive chain eras (same base hue).
enum DateRangeBandFillStyle {
  /// Even wash across the band.
  wash,

  /// Stronger at the top, fading downward.
  fadeDown,

  /// Stronger at the bottom, fading upward.
  fadeUp,

  /// Stronger on the left edge of the era.
  fadeRight,

  /// Soft mid-band veil (stronger through the vertical center).
  midVeil,
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
  DateRangeBandFillStyle fillStyle = DateRangeBandFillStyle.wash,
  double fillAlpha = 0.07,
}) {
  final bandRect = Rect.fromLTRB(
    geometry.leftX,
    layout.top,
    geometry.rightX,
    layout.bottom,
  );
  if (fillPaint != null) {
    canvas.drawRect(bandRect, fillPaint);
  } else if (fillColor != null) {
    canvas.drawRect(
      bandRect,
      _bandFillPaint(
        color: fillColor,
        bandRect: bandRect,
        style: fillStyle,
        alpha: fillAlpha,
      ),
    );
  }
  if (geometry.drawLeftEdge) {
    canvas.drawLine(
      Offset(geometry.leftX, layout.top),
      Offset(geometry.leftX, layout.bottom),
      edgePaint,
    );
  }
  if (geometry.drawRightEdge) {
    canvas.drawLine(
      Offset(geometry.rightX, layout.top),
      Offset(geometry.rightX, layout.bottom),
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
  final mist = color.withValues(alpha: alpha * 0.15);
  final clear = color.withValues(alpha: 0);

  final Gradient gradient = switch (style) {
    DateRangeBandFillStyle.wash => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [peak, peak],
      ),
    DateRangeBandFillStyle.fadeDown => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [peak, clear],
      ),
    DateRangeBandFillStyle.fadeUp => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [peak, clear],
      ),
    DateRangeBandFillStyle.fadeRight => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [peak, mist, clear],
        stops: const [0.0, 0.35, 1.0],
      ),
    DateRangeBandFillStyle.midVeil => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [clear, peak, mist, clear],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ),
  };

  return Paint()
    ..shader = gradient.createShader(bandRect)
    ..style = PaintingStyle.fill;
}
