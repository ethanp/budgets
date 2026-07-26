import 'dart:math' as math;

import 'package:spend_trends/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/painting.dart';

const _months = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class ChartDateLayout {
  ChartDateLayout({
    required Size size,
    required double leftPadding,
    required double rightPadding,
    required double topPadding,
    required double bottomPadding,
    required this.minDate,
    required this.maxDate,
  }) {
    left = leftPadding;
    right = size.width - rightPadding;
    top = topPadding;
    bottom = size.height - bottomPadding;
    width = right - left;
    height = bottom - top;
    _dateRangeSeconds = maxDate.difference(minDate).inSeconds.toDouble();
  }

  final DateTime minDate;
  final DateTime maxDate;
  late final double left, right, top, bottom, width, height;
  late final double _dateRangeSeconds;

  double xForDate(DateTime date) {
    if (_dateRangeSeconds == 0) return left + width / 2;
    return left +
        (date.difference(minDate).inSeconds / _dateRangeSeconds) * width;
  }

  DateTime dateForX(double x) {
    if (width == 0) return minDate;
    final fraction = ((x - left) / width).clamp(0.0, 1.0);
    final seconds = (fraction * _dateRangeSeconds).round();
    return minDate.add(Duration(seconds: seconds));
  }

  List<DateTime> dateTicks() {
    final spanDays = maxDate.difference(minDate).inDays;
    if (spanDays <= 0) return [minDate];

    // Multi-month charts: calendar quarters (Jan / Apr / Jul / Oct).
    if (spanDays > 90) return _quarterMonthTicks();

    final targetCount = math.max(3, (width / 70).round());
    final stepDays = math.max(1, (spanDays / targetCount).round());
    final ticks = <DateTime>[minDate];
    var cursor = minDate.shiftedByDays(stepDays);
    final minGap = stepDays ~/ 2;
    while (cursor.isBefore(maxDate.shiftedByDays(-minGap))) {
      ticks.add(cursor);
      cursor = cursor.shiftedByDays(stepDays);
    }
    ticks.add(maxDate);
    return ticks;
  }

  /// Firsts of Jan, Apr, Jul, Oct that fall inside the chart range.
  List<DateTime> _quarterMonthTicks() {
    final rangeStart = minDate.startOfDay;
    final rangeEnd = maxDate.startOfDay;
    final quarterStartMonth = ((rangeStart.month - 1) ~/ 3) * 3 + 1;
    var cursor = DateTime(rangeStart.year, quarterStartMonth);
    if (cursor.isBefore(rangeStart)) {
      cursor = DateTime(cursor.year, cursor.month + 3);
    }

    final ticks = <DateTime>[];
    while (!cursor.isAfter(rangeEnd)) {
      ticks.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 3);
    }
    return ticks;
  }

  void drawDateLabels(Canvas canvas, {required TextStyle labelStyle}) {
    final spanDays = maxDate.difference(minDate).inDays;
    final tickPaint = Paint()
      ..color = AppColors.textSupport
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const tickLength = 5.0;

    String formatLabel(DateTime date) {
      if (spanDays > 60) return _months[date.month];
      return '${date.month}/${date.day}';
    }

    for (final date in dateTicks()) {
      final tickX = xForDate(date);
      canvas.drawLine(
        Offset(tickX, bottom),
        Offset(tickX, bottom + tickLength),
        tickPaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(text: formatLabel(date), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = (tickX - textPainter.width / 2).clamp(
        left - 4,
        right - textPainter.width + 4,
      );
      textPainter.paint(canvas, Offset(labelX, bottom + tickLength + 3));
    }
  }

  void drawAxes(Canvas canvas) {
    final axisPaint = Paint()
      ..color = AppColors.textDim.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), axisPaint);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), axisPaint);
  }

  /// X positions of Jan-1 year boundaries drawn across a multi-year span.
  List<double> yearBoundaryXs() {
    if (minDate.year == maxDate.year) return const [];
    return [
      for (var year = minDate.year + 1; year <= maxDate.year; year++)
        xForDate(DateTime(year)),
    ];
  }

  /// Year grid lines span the plot; labels sit at [yearLabelY] (date lane).
  void drawYearBoundaries(
    Canvas canvas, {
    required double yearLabelY,
    required TextStyle labelStyle,
  }) {
    final boundaryXs = yearBoundaryXs();
    if (boundaryXs.isEmpty) return;

    final linePaint = Paint()
      ..color = AppColors.textDim.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    for (var index = 0; index < boundaryXs.length; index++) {
      final boundaryX = boundaryXs[index];
      final year = minDate.year + 1 + index;
      canvas.drawLine(
        Offset(boundaryX, top),
        Offset(boundaryX, bottom),
        linePaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$year',
          style: labelStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(boundaryX + 4, yearLabelY));
    }
  }
}
