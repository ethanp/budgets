import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/widgets/app_card.dart';

/// Sticky Activity chrome: search and hide-auto-categorized.
class ActivityFilterBar extends StatelessWidget {
  const ActivityFilterBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.hideRuleMatched,
    required this.searchMatchCount,
    required this.visibleCount,
    required this.onHideRuleMatchedChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool hideRuleMatched;
  final int searchMatchCount;
  final int visibleCount;
  final ValueChanged<bool> onHideRuleMatchedChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.spaceLg,
          AppMetrics.spaceLg,
          AppMetrics.spaceLg,
          AppMetrics.spaceSm,
        ),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search description, category, account…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppMetrics.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppMetrics.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppMetrics.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.accentGlow,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppMetrics.spaceSm),
            _RuleMatchFilterToggle(
              hideRuleMatched: hideRuleMatched,
              hiddenCount: searchMatchCount - visibleCount,
              visibleCount: visibleCount,
              onChanged: onHideRuleMatchedChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleMatchFilterToggle extends StatelessWidget {
  const _RuleMatchFilterToggle({
    required this.hideRuleMatched,
    required this.hiddenCount,
    required this.visibleCount,
    required this.onChanged,
  });

  final bool hideRuleMatched;
  final int hiddenCount;
  final int visibleCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.spaceMd,
        vertical: AppMetrics.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hide auto-categorized',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  hideRuleMatched
                      ? '$visibleCount shown · $hiddenCount hidden'
                      : 'Showing all loaded transactions',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: hideRuleMatched,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Sum of the currently visible Activity list (right-pane chrome).
class ActivityVisibleSumBar extends StatelessWidget {
  const ActivityVisibleSumBar({
    required this.visibleTransactions,
  });

  final List<BankTransaction> visibleTransactions;

  @override
  Widget build(BuildContext context) {
    var netCents = 0;
    var inflowCents = 0;
    var outflowCents = 0;
    for (final transaction in visibleTransactions) {
      netCents += transaction.amountCents;
      if (transaction.isInflow) {
        inflowCents += transaction.amountCents;
      } else if (transaction.isOutflow) {
        outflowCents += transaction.amountCents;
      }
    }

    final netColor = netCents > 0
        ? AppColors.success
        : netCents < 0
            ? AppColors.danger
            : AppColors.textSecondary;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.spaceMd,
        vertical: AppMetrics.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sum visible list',
            style: AppText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppMetrics.spaceXs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${visibleTransactions.length} '
                  '${visibleTransactions.length == 1 ? 'transaction' : 'transactions'}',
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppMetrics.spaceMd),
              Text(
                formatCents(netCents),
                style: AppText.section.copyWith(color: netColor),
                maxLines: 1,
              ),
            ],
          ),
          if (inflowCents != 0 || outflowCents != 0) ...[
            const SizedBox(height: AppMetrics.spaceXs),
            Text(
              'In ${formatCents(inflowCents)} · Out ${formatCents(outflowCents)}',
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }
}
