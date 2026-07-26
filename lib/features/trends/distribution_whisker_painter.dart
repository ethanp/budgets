import 'package:spend_trends/features/trends/category_trend_distribution.dart';
import 'package:spend_trends/features/trends/trend_value_scale.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Shared stroke/mark drawing for whiskers and the symbol key.
class DistributionWhiskerMarks {
  DistributionWhiskerMarks._();

  static void paintRangeStem(
    Canvas canvas, {
    required Offset top,
    required Offset bottom,
    required Color color,
    double strokeWidth = 1.5,
    double capHalfWidth = 5,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(top, bottom, paint);
    canvas.drawLine(
      Offset(top.dx - capHalfWidth, top.dy),
      Offset(top.dx + capHalfWidth, top.dy),
      paint,
    );
    canvas.drawLine(
      Offset(bottom.dx - capHalfWidth, bottom.dy),
      Offset(bottom.dx + capHalfWidth, bottom.dy),
      paint,
    );
  }

  static void paintMedianTick(
    Canvas canvas, {
    required Offset center,
    required Color color,
    double halfWidth = 7,
    double strokeWidth = 1.5,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - halfWidth, center.dy),
      Offset(center.dx + halfWidth, center.dy),
      paint,
    );
  }

  static void paintAverageCross(
    Canvas canvas, {
    required Offset center,
    required Color color,
    double arm = 4,
    double strokeWidth = 1.5,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - arm, center.dy - arm),
      Offset(center.dx + arm, center.dy + arm),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - arm, center.dy + arm),
      Offset(center.dx + arm, center.dy - arm),
      paint,
    );
  }

  static void paintNowDot(
    Canvas canvas, {
    required Offset center,
    required Color color,
    double radius = 3.5,
    Color? ringColor,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    if (ringColor != null) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }
}

/// Vertical min–max whisker with median tick, avg cross, and current dot.
class DistributionWhiskerPainter extends CustomPainter {
  DistributionWhiskerPainter({
    required this.distribution,
    required this.scale,
    required this.seriesColor,
    required this.isDimmed,
  });

  final CategoryTrendDistribution distribution;
  final TrendValueScale scale;
  final Color seriesColor;
  final bool isDimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final color = isDimmed ? AppColors.textDim : seriesColor;
    final stemColor = color.withValues(alpha: isDimmed ? 0.45 : 0.85);

    final centerX = size.width / 2;
    final minY = scale.yFromTop(distribution.minCents, size.height);
    final maxY = scale.yFromTop(distribution.maxCents, size.height);
    final medianY = scale.yFromTop(distribution.medianCents, size.height);
    final averageY = scale.yFromTop(distribution.averageCents, size.height);
    final currentY = scale.yFromTop(distribution.currentCents, size.height);

    DistributionWhiskerMarks.paintRangeStem(
      canvas,
      top: Offset(centerX, maxY),
      bottom: Offset(centerX, minY),
      color: stemColor,
    );
    DistributionWhiskerMarks.paintMedianTick(
      canvas,
      center: Offset(centerX, medianY),
      color: color,
    );
    DistributionWhiskerMarks.paintAverageCross(
      canvas,
      center: Offset(centerX, averageY),
      color: color,
    );
    DistributionWhiskerMarks.paintNowDot(
      canvas,
      center: Offset(centerX, currentY),
      color: color,
      ringColor: isDimmed ? null : AppColors.backgroundDepth2,
    );
  }

  @override
  bool shouldRepaint(covariant DistributionWhiskerPainter oldDelegate) {
    return oldDelegate.distribution != distribution ||
        oldDelegate.scale.maxCents != scale.maxCents ||
        oldDelegate.seriesColor != seriesColor ||
        oldDelegate.isDimmed != isDimmed;
  }
}

enum DistributionWhiskerGlyph {
  range,
  median,
  average,
  now,
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final DistributionWhiskerGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    switch (glyph) {
      case DistributionWhiskerGlyph.range:
        DistributionWhiskerMarks.paintRangeStem(
          canvas,
          top: Offset(center.dx, 2),
          bottom: Offset(center.dx, size.height - 2),
          color: color,
          capHalfWidth: 4,
        );
      case DistributionWhiskerGlyph.median:
        DistributionWhiskerMarks.paintMedianTick(
          canvas,
          center: center,
          color: color,
          halfWidth: 6,
        );
      case DistributionWhiskerGlyph.average:
        DistributionWhiskerMarks.paintAverageCross(
          canvas,
          center: center,
          color: color,
        );
      case DistributionWhiskerGlyph.now:
        DistributionWhiskerMarks.paintNowDot(
          canvas,
          center: center,
          color: color,
          ringColor: AppColors.backgroundDepth3,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// Dashed horizontals at each readable Y tick of the shared whisker scale.
class DistributionWhiskerGridPainter extends CustomPainter {
  const DistributionWhiskerGridPainter({required this.scale});

  final TrendValueScale scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.7)
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;
    for (final tickCents in scale.tickCents) {
      if (tickCents <= 0) continue;
      final y = scale.yFromTop(tickCents, size.height);
      _drawDashedHorizontal(canvas, y: y, width: size.width, paint: paint);
    }
  }

  void _drawDashedHorizontal(
    Canvas canvas, {
    required double y,
    required double width,
    required Paint paint,
    double dashLength = 4,
    double gapLength = 3,
  }) {
    var x = 0.0;
    var drawingDash = true;
    while (x < width) {
      final next = drawingDash ? x + dashLength : x + gapLength;
      final end = next > width ? width : next;
      if (drawingDash) {
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x = end;
      drawingDash = !drawingDash;
    }
  }

  @override
  bool shouldRepaint(covariant DistributionWhiskerGridPainter oldDelegate) =>
      oldDelegate.scale.maxCents != scale.maxCents ||
      oldDelegate.scale.tickCents.length != scale.tickCents.length;
}

/// Compact key explaining whisker marks (range / med / avg / now).
class DistributionWhiskerSymbolKey extends StatelessWidget {
  const DistributionWhiskerSymbolKey({super.key});

  static const _entries = <(DistributionWhiskerGlyph, String)>[
    (DistributionWhiskerGlyph.range, 'min–max'),
    (DistributionWhiskerGlyph.median, 'median'),
    (DistributionWhiskerGlyph.average, 'avg'),
    (DistributionWhiskerGlyph.now, 'now'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.borderDepth1.withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < _entries.length; index++) ...[
                if (index > 0) ...[
                  HSpace.sm,
                  Container(
                    width: 1,
                    height: 14,
                    color: AppColors.borderDepth1.withValues(alpha: 0.7),
                  ),
                  HSpace.sm,
                ],
                _keyItem(glyph: _entries[index].$1, label: _entries[index].$2),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pair: all-time (left) · past year (right)',
            style: AppText.caption.copyWith(
              color: AppColors.textDim,
              fontSize: 10,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyItem({
    required DistributionWhiskerGlyph glyph,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: glyph == DistributionWhiskerGlyph.range ? 12 : 14,
          height: glyph == DistributionWhiskerGlyph.range ? 16 : 14,
          child: CustomPaint(
            painter: _GlyphPainter(glyph, AppColors.textBody),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppText.caption.copyWith(
            color: AppColors.textSupport,
            fontSize: 11,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
