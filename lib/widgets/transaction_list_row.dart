import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/theme/finance_colors.dart';

/// Metal transaction row shared by Activity and pull-progress lists.
///
/// Layout: color bar | [leading cells…] | title | amount | [trailing].
class TransactionListRow extends StatelessWidget {
  const TransactionListRow({
    required this.categoryColor,
    required this.title,
    required this.amountCents,
    required this.amountColor,
    this.leadingCells = const [],
    this.trailing,
    this.onActivated,
    this.selected = false,
  });

  final Color categoryColor;
  final String title;
  final int amountCents;
  final Color amountColor;
  final List<Widget> leadingCells;
  final Widget? trailing;
  final VoidCallback? onActivated;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ESurface(
      kind: selected ? ESurfaceKind.tinted : ESurfaceKind.row,
      accent: selected ? FinanceColors.accentPrimary : null,
      onActivated: onActivated,
      borderRadius: ELayout.borderRadiusMd,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: categoryColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ELayout.spaceMd,
                  vertical: ELayout.spaceMd,
                ),
                child: Row(
                  children: [
                    for (final cell in leadingCells) ...[
                      cell,
                      const SizedBox(width: ELayout.spaceSm),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: EText.body.medium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: EColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: ELayout.spaceMd),
                    Text(
                      formatCents(amountCents),
                      style: EText.body.medium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: amountColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: ELayout.spaceSm),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fixed-width leading cell used by Activity column alignment.
  static Widget cell({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }
}
