import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/theme/finance_colors.dart';

/// One matching transaction in a rule-impact preview list.
///
/// Row: [checkbox | category | title | amount] with date under the title.
class RuleImpactMatchRow extends StatelessWidget {
  const RuleImpactMatchRow({
    required this.transaction,
    required this.currentCategoryName,
    required this.selected,
    required this.onSelectionChanged,
  });

  final BankTransaction transaction;
  final String currentCategoryName;
  final bool selected;
  final ValueChanged<bool> onSelectionChanged;

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
    final dateLabel = DateFormat.yMMMd().format(transaction.postedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelectionChanged(!selected),
        child: ESurface(
          kind: selected ? ESurfaceKind.tinted : ESurfaceKind.row,
          accent: selected ? FinanceColors.accentPrimary : null,
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceMd,
            vertical: ELayout.spaceSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                value: selected,
                onChanged: (value) => onSelectionChanged(value ?? false),
              ),
              const SizedBox(width: ELayout.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            style: EText.body.medium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: ELayout.spaceSm),
                        Text(
                          formatCents(transaction.amountCents),
                          style: EText.body.medium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currentCategoryName · $dateLabel',
                      style: EText.caption.copyWith(
                        color: currentCategoryName == 'Uncategorized'
                            ? EColors.textMuted
                            : FinanceColors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
