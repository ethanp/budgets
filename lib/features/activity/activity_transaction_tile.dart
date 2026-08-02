import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/activity/activity_column_widths.dart';
import 'package:spend_trends/theme/finance_colors.dart';
import 'package:spend_trends/util/category_color.dart';
import 'package:spend_trends/widgets/transaction_list_row.dart';

/// One Activity row: [category | account | title | amount].
class ActivityTransactionTile extends StatelessWidget {
  const ActivityTransactionTile({
    required this.transaction,
    required this.account,
    required this.category,
    required this.onTap,
    required this.columnWidths,
    this.onRuleTap,
    this.selected = false,
  });

  final BankTransaction transaction;
  final Account? account;
  final SpendCategory? category;
  final VoidCallback onTap;
  final VoidCallback? onRuleTap;
  final bool selected;
  final ActivityColumnWidths columnWidths;

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryColor.forCategoryId(
      category?.id,
      categoryName: category?.name,
      groupId: category?.groupId,
    );
    final merchantName = transaction.rawDescription.isEmpty
        ? transaction.normalizedMerchant
        : transaction.rawDescription;

    return TransactionListRow(
      categoryColor: categoryColor,
      title: merchantName,
      amountCents: transaction.amountCents,
      amountColor: _amountColor,
      selected: selected,
      onTap: onTap,
      leadingCells: [
        TransactionListRow.cell(
          width: columnWidths.category,
          child: Text(
            category?.name ?? 'Uncategorized',
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: categoryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TransactionListRow.cell(
          width: columnWidths.account,
          child: Text(
            account?.displayNameWithInstitution ?? '—',
            style: AppText.caption.copyWith(
              color: AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      trailing: _trailing(),
    );
  }

  Widget? _trailing() {
    final statusIcons = _statusIcons();
    final ruleButton = onRuleTap == null
        ? null
        : Tooltip(
            message: 'Manage categorization rule',
            child: TextButton(
              onPressed: onRuleTap,
              style: TextButton.styleFrom(
                foregroundColor: FinanceColors.accentPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.spaceSm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Rule',
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: FinanceColors.accentPrimary,
                ),
              ),
            ),
          );
    if (statusIcons == null && ruleButton == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?statusIcons,
        if (statusIcons != null && ruleButton != null)
          const SizedBox(width: AppMetrics.spaceXs),
        ?ruleButton,
      ],
    );
  }

  Widget? _statusIcons() {
    if (!transaction.pending &&
        !transaction.excluded &&
        transaction.recurringSeries == null) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transaction.pending)
          const Icon(
            Icons.schedule,
            size: 15,
            color: AppColors.warning,
          ),
        if (transaction.excluded)
          const Icon(
            Icons.visibility_off,
            size: 15,
            color: AppColors.danger,
          ),
        if (transaction.recurringSeries != null)
          const Icon(
            Icons.sync,
            size: 15,
            color: FinanceColors.accentPrimary,
          ),
      ],
    );
  }

  Color get _amountColor {
    if (category?.isTransfer == true) {
      return FinanceColors.accentSecondary;
    }
    if (transaction.isInflow || category?.isIncome == true) {
      return AppColors.success;
    }
    return AppColors.danger;
  }
}
