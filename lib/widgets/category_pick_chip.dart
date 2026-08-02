import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

/// Colored selectable chip used in category pickers.
class CategoryPickChip extends StatelessWidget {
  const CategoryPickChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.spaceMd,
          vertical: AppMetrics.spaceSm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.28 : 0.14),
          borderRadius: AppMetrics.borderRadius(AppMetrics.radiusSm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.85 : 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
