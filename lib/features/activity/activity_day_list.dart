import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/categorizer.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/activity/activity_column_widths.dart';
import 'package:spend_trends/features/activity/activity_transaction_tile.dart';

/// Day-grouped Activity transaction list (sliver).
class ActivityDayListSliver extends StatelessWidget {
  const ActivityDayListSliver({
    required this.transactions,
    required this.accounts,
    required this.categories,
    required this.ruleMatchIndex,
    required this.explainingByTransactionId,
    required this.selectedTransactionId,
    required this.columnWidths,
    required this.onTransactionTap,
    required this.onRuleTap,
  });

  final List<BankTransaction> transactions;
  final Map<String, Account> accounts;
  final Map<String, SpendCategory> categories;
  final RuleMatchIndex ruleMatchIndex;
  final Map<String, CategorizationRule?> explainingByTransactionId;
  final String? selectedTransactionId;
  final ActivityColumnWidths columnWidths;
  final void Function(BankTransaction transaction) onTransactionTap;
  final void Function(CategorizationRule rule) onRuleTap;

  @override
  Widget build(BuildContext context) {
    final listItems = ActivityDayGrouping.items(transactions);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.spaceLg,
        0,
        AppMetrics.spaceLg,
        AppMetrics.spaceLg,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final listItem = listItems[index];
            if (listItem is ActivityDayHeader) {
              return _ActivityDayHeaderTile(
                label: listItem.label,
                isFirst: index == 0,
              );
            }
            final transaction =
                (listItem as ActivityDayTransactionItem).transaction;
            final account = accounts[transaction.accountId];
            final category = categories[transaction.effectiveCategoryId];
            final explainingRule = explainingByTransactionId[transaction.id] ??
                ruleMatchIndex.explainingRule(transaction);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.spaceSm),
              child: ActivityTransactionTile(
                transaction: transaction,
                account: account,
                category: category,
                selected: selectedTransactionId == transaction.id,
                columnWidths: columnWidths,
                onTap: () => onTransactionTap(transaction),
                onRuleTap: explainingRule != null &&
                        explainingRule.beatsImportDefault
                    ? () => onRuleTap(explainingRule)
                    : null,
              ),
            );
          },
          childCount: listItems.length,
        ),
      ),
    );
  }
}

/// Groups transactions under Today / Yesterday / weekday headers.
class ActivityDayGrouping {
  ActivityDayGrouping._();

  static List<ActivityDayListItem> items(List<BankTransaction> transactions) {
    final today = DateTime.now().startOfDay;
    final yesterday = today.subtract(const Duration(days: 1));
    final listItems = <ActivityDayListItem>[];
    DateTime? currentDay;

    for (final transaction in transactions) {
      final day = transaction.postedAt.toLocal().startOfDay;
      if (currentDay != day) {
        currentDay = day;
        listItems.add(
          ActivityDayHeader(label: _dayHeaderLabel(day, today, yesterday)),
        );
      }
      listItems.add(ActivityDayTransactionItem(transaction: transaction));
    }
    return listItems;
  }

  static String _dayHeaderLabel(
    DateTime day,
    DateTime today,
    DateTime yesterday,
  ) {
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    if (day.year == today.year) {
      return DateFormat('EEEE, MMM d').format(day);
    }
    return DateFormat('EEEE, MMM d, y').format(day);
  }
}

sealed class ActivityDayListItem {
  const ActivityDayListItem();
}

class ActivityDayHeader extends ActivityDayListItem {
  const ActivityDayHeader({required this.label});

  final String label;
}

class ActivityDayTransactionItem extends ActivityDayListItem {
  const ActivityDayTransactionItem({required this.transaction});

  final BankTransaction transaction;
}

class _ActivityDayHeaderTile extends StatelessWidget {
  const _ActivityDayHeaderTile({
    required this.label,
    required this.isFirst,
  });

  final String label;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? AppMetrics.spaceXs : AppMetrics.spaceLg,
        bottom: AppMetrics.spaceSm,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: AppMetrics.spaceMd),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}
