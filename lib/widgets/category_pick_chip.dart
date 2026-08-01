import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Colored selectable chip used in category pickers.
class CategoryPickChip extends StatelessWidget {
  const CategoryPickChip({
    super.key,
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.28 : 0.14),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.85 : 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppText.body.small.semibold.copyWith(
            color: color,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
