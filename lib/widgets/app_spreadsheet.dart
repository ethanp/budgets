import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Fixed-width cell so sibling rows share a column edge.
class AppSpreadsheetCell extends StatelessWidget {
  const AppSpreadsheetCell({
    super.key,
    required this.width,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  final double width;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: child,
      ),
    );
  }
}

/// Leading content + a shared-width trailing column (right-aligned).
///
/// Use the same [trailingWidth] across sibling rows so values form a column,
/// sized to the widest cell (see [TextsPaintMeasure.maxPaintedWidth]).
class AppSpreadsheetRow extends StatelessWidget {
  const AppSpreadsheetRow({
    super.key,
    required this.leading,
    required this.trailing,
    required this.trailingWidth,
    this.gap = AppSpacing.md,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final Widget leading;
  final Widget trailing;
  final double trailingWidth;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Expanded(child: leading),
        SizedBox(width: gap),
        AppSpreadsheetCell(
          width: trailingWidth,
          alignment: Alignment.centerRight,
          child: trailing,
        ),
      ],
    );
  }
}
