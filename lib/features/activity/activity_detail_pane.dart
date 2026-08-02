import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/activity/activity_filter_bar.dart';
import 'package:spend_trends/features/activity/recategorize_form.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';

/// Activity right pane: visible sum, uncategorized overview, or categorizer.
class ActivityDetailPane extends StatelessWidget {
  const ActivityDetailPane({
    required this.uncategorized,
    required this.visibleTransactions,
    required this.selected,
    required this.uncategorizedOnly,
    required this.onShowUncategorized,
    required this.onClearUncategorizedFilter,
    required this.onCategorized,
  });

  /// Same uncategorized set the list uses for “Show uncategorized”.
  final List<BankTransaction> uncategorized;
  final List<BankTransaction> visibleTransactions;
  final BankTransaction? selected;
  final bool uncategorizedOnly;
  final VoidCallback onShowUncategorized;
  final VoidCallback onClearUncategorizedFilter;
  final VoidCallback onCategorized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.spaceLg,
            AppMetrics.spaceLg,
            AppMetrics.spaceLg,
            AppMetrics.spaceSm,
          ),
          child: ActivityVisibleSumBar(
            visibleTransactions: visibleTransactions,
          ),
        ),
        Expanded(child: _detailBody()),
      ],
    );
  }

  Widget _detailBody() {
    if (selected != null) {
      return KeyedSubtree(
        key: ValueKey(selected!.id),
        child: RecategorizeForm(
          transaction: selected!,
          onCompleted: (categoryId) {
            if (categoryId != null) onCategorized();
          },
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.spaceLg,
        AppMetrics.spaceSm,
        AppMetrics.spaceLg,
        AppMetrics.spaceLg,
      ),
      children: [_uncategorizedOverview()],
    );
  }

  Widget _uncategorizedOverview() {
    final yearMonth = DateTime.now().yearMonthKey;
    var thisMonthCount = 0;
    var thisMonthCents = 0;
    var earlierCount = 0;
    var earlierCents = 0;
    var outflowCents = 0;
    for (final transaction in uncategorized) {
      final amount = transaction.amountCents.abs();
      if (transaction.isOutflow) outflowCents += amount;
      if (transaction.postedAt.toLocal().yearMonthKey == yearMonth) {
        thisMonthCount += 1;
        thisMonthCents += amount;
      } else {
        earlierCount += 1;
        earlierCents += amount;
      }
    }
    final totalCount = thisMonthCount + earlierCount;
    final totalCents = thisMonthCents + earlierCents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Uncategorized', style: AppText.section),
        const SizedBox(height: AppMetrics.spaceSm),
        Text(
          totalCount == 0
              ? 'No uncategorized transactions.'
              : '$totalCount uncategorized · ${formatCents(totalCents)}',
          style: AppText.section.copyWith(fontWeight: FontWeight.w600),
        ),
        if (totalCount > 0) ...[
          const SizedBox(height: AppMetrics.spaceXs),
          Text(
            _uncategorizedBreakdown(
              thisMonthCount: thisMonthCount,
              thisMonthCents: thisMonthCents,
              earlierCount: earlierCount,
              earlierCents: earlierCents,
            ),
            style: AppText.caption,
          ),
          if (outflowCents > 0) ...[
            const SizedBox(height: AppMetrics.spaceXs),
            Text(
              '${formatCents(outflowCents)} outflow',
              style: AppText.caption,
            ),
          ],
        ],
        const SizedBox(height: AppMetrics.spaceSm),
        Text(
          'Unlabeled activity — especially outflows — skews the annual spend '
          'pace that FI timelines will use. Clear every month, not just the '
          'current one.',
          style: AppText.caption,
        ),
        const SizedBox(height: AppMetrics.spaceLg),
        if (uncategorizedOnly)
          TextButton(
            onPressed: onClearUncategorizedFilter,
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Show all transactions'),
          )
        else if (totalCount > 0)
          AppPrimaryButton(
            onPressed: onShowUncategorized,
            child: const Text('Show uncategorized'),
          ),
      ],
    );
  }

  String _uncategorizedBreakdown({
    required int thisMonthCount,
    required int thisMonthCents,
    required int earlierCount,
    required int earlierCents,
  }) {
    if (thisMonthCount == 0) {
      return '$earlierCount earlier · ${formatCents(earlierCents)} · '
          'nothing this month';
    }
    if (earlierCount == 0) {
      return '$thisMonthCount this month · ${formatCents(thisMonthCents)}';
    }
    return '$thisMonthCount this month · ${formatCents(thisMonthCents)} · '
        '$earlierCount earlier · ${formatCents(earlierCents)}';
  }
}
