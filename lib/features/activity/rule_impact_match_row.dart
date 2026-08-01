import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// One matching transaction in a rule-impact preview list.
class RuleImpactMatchRow extends StatelessWidget {
  const RuleImpactMatchRow({
    super.key,
    required this.transaction,
    required this.currentCategoryName,
    required this.selected,
    required this.onChanged,
  });

  final BankTransaction transaction;
  final String currentCategoryName;
  final bool selected;
  final ValueChanged<bool> onChanged;

  static String categoryLabel(
    BankTransaction transaction,
    Map<String, String> categoryNameById,
  ) {
    final categoryId = transaction.effectiveCategoryId;
    if (categoryId == null) return 'Uncategorized';
    return categoryNameById[categoryId] ?? 'Unknown category';
  }

  String get _title => transaction.rawDescription.isEmpty
      ? transaction.normalizedMerchant
      : transaction.rawDescription;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: AppComponents.primaryCard,
          child: Row(
            children: [
              CupertinoCheckbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
              ),
              HSpace.sm,
              Expanded(child: _details()),
              Text(
                formatCents(transaction.amountCents),
                style: AppText.body.medium.semibold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details() {
    final dateLabel =
        DateFormat.yMMMd().format(transaction.postedAt.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: AppText.body.medium.semibold,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          currentCategoryName,
          style: AppText.body.small.copyWith(
            color: currentCategoryName == 'Uncategorized'
                ? AppColors.textDim
                : AppColors.accentPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(dateLabel, style: AppText.body.small),
      ],
    );
  }
}
