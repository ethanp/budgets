import 'package:ethan_ui/ethan_ui.dart';
import 'package:spend_trends/theme/finance_colors.dart';
import 'package:flutter/material.dart';

/// Soft card fill/border pulled toward [tint] over metal surface.
BoxDecoration appTintedCardDecoration({
  required Color tint,
  bool selected = false,
}) {
  final fillAlpha = selected ? 0.22 : 0.12;
  final borderAlpha = selected ? 0.55 : 0.35;
  return BoxDecoration(
    color: Color.alphaBlend(
      tint.withValues(alpha: fillAlpha),
      AppColors.surface,
    ),
    borderRadius: AppMetrics.borderRadius(AppMetrics.radiusMd),
    border: Border.all(
      color: tint.withValues(alpha: borderAlpha),
      width: selected ? 1.5 : 1,
    ),
  );
}

/// Compact horizontal fact columns — title capped with ellipsis; amount hugs.
///
/// Does not stretch title and amount to opposite edges of a wide window.
/// Pass the same [amountWidth] across sibling rows so amounts align inside a
/// narrow browse pane.
class AppCompactFactRow extends StatelessWidget {
  const AppCompactFactRow({
    required this.title,
    this.leading,
    this.caption,
    this.amount,
    this.amountWidth,
    this.trailing,
    this.titleMaxWidth = 260,
    this.tintColor,
    this.selected = false,
    this.decorate = true,
    this.onTap,
    this.padding = const EdgeInsets.all(AppMetrics.spaceMd),
  });

  final Widget? leading;
  final String title;
  final String? caption;
  final Widget? amount;
  final double? amountWidth;
  final Widget? trailing;
  final double titleMaxWidth;
  final Color? tintColor;
  final bool selected;

  /// When false, renders only the compact columns (caller owns chrome).
  final bool decorate;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppMetrics.spaceMd),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: titleMaxWidth),
            child: _titleColumn(),
          ),
          if (amount != null) ...[
            const SizedBox(width: AppMetrics.spaceMd),
            if (amountWidth != null)
              SizedBox(
                width: amountWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: amount,
                ),
              )
            else
              amount!,
          ],
          if (trailing != null) ...[
            const SizedBox(width: AppMetrics.spaceSm),
            trailing!,
          ],
        ],
      ),
    );

    final Widget body;
    if (!decorate) {
      body = row;
    } else if (tintColor != null) {
      body = Container(
        decoration: appTintedCardDecoration(
          tint: tintColor!,
          selected: selected,
        ),
        child: row,
      );
    } else {
      body = AppSurface(
        kind: selected ? AppSurfaceKind.tinted : AppSurfaceKind.row,
        accent: selected ? FinanceColors.accentPrimary : null,
        child: row,
      );
    }

    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }

  Widget _titleColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppText.section.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null)
          Text(
            caption!,
            style: AppText.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
