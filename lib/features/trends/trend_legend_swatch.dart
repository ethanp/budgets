import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';

/// Color chip for a trend series (solid, dotted, or long-dash guide).
class TrendLegendSwatch extends StatelessWidget {
  const TrendLegendSwatch({
    required this.series,
    required this.isHidden,
  });

  final CategoryTrendSeries series;
  final bool isHidden;

  @override
  Widget build(BuildContext context) {
    final color = isHidden ? EColors.textMuted : series.lineColor;
    if (series.guide || series.dotted) {
      return SizedBox(
        width: 16,
        height: 10,
        child: CustomPaint(
          painter: _DottedLegendSwatchPainter(
            color,
            longDash: series.guide,
          ),
        ),
      );
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _DottedLegendSwatchPainter extends CustomPainter {
  _DottedLegendSwatchPainter(this.color, {this.longDash = false});

  final Color color;
  final bool longDash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = longDash ? 1.5 : 2
      ..strokeCap = StrokeCap.round;
    final dash = longDash ? 5.0 : 3.0;
    final gap = longDash ? 3.0 : 2.0;
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
      color != oldDelegate.color || longDash != oldDelegate.longDash;
}
