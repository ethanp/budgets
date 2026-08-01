import 'package:spend_trends/features/activity/overlapping_merchant_contains_rules.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Chips for existing contains-rules that overlap a candidate pattern.
class ExistingRuleOverlaps extends StatelessWidget {
  const ExistingRuleOverlaps({super.key, required this.overlaps});

  final List<RelatedExistingRule> overlaps;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: overlaps.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overlaps existing rules',
                    style: AppText.caption.copyWith(
                      color: AppColors.textDim,
                      letterSpacing: 0.2,
                    ),
                  ),
                  VSpace.xs,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final entry in overlaps)
                        _RelatedRuleChip(entry: entry),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _RelatedRuleChip extends StatelessWidget {
  const _RelatedRuleChip({required this.entry});

  final RelatedExistingRule entry;

  @override
  Widget build(BuildContext context) {
    final accent = switch (entry.relation) {
      RelatedRuleRelation.same => AppColors.accentPrimary,
      RelatedRuleRelation.broader => AppColors.accentSecondary,
      RelatedRuleRelation.narrower => AppColors.housing,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.relation.label} · ',
              style: AppText.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '“${entry.rule.pattern}” → ${entry.categoryName}',
              style: AppText.caption.copyWith(color: AppColors.textBody),
            ),
          ],
        ),
      ),
    );
  }
}
