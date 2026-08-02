import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/features/activity/overlapping_merchant_contains_rules.dart';
import 'package:spend_trends/theme/finance_colors.dart';

/// Chips for existing contains-rules that overlap a candidate pattern.
class ExistingRuleOverlaps extends StatelessWidget {
  const ExistingRuleOverlaps({required this.overlaps});

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
              padding: const EdgeInsets.only(top: AppMetrics.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overlaps existing rules',
                    style: AppText.caption.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.spaceXs),
                  Wrap(
                    spacing: AppMetrics.spaceSm,
                    runSpacing: AppMetrics.spaceSm,
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
      RelatedRuleRelation.same => FinanceColors.accentPrimary,
      RelatedRuleRelation.broader => FinanceColors.accentSecondary,
      RelatedRuleRelation.narrower => FinanceColors.housing,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.spaceMd,
        vertical: AppMetrics.spaceSm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
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
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
