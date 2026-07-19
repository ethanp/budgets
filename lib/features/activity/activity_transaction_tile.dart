import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/category_color.dart';
import 'package:budgets/util/money_format.dart';
import 'package:flutter/cupertino.dart';

/// One Activity row: merchant + amount first, then category, then metadata.
class ActivityTransactionTile extends StatelessWidget {
  const ActivityTransactionTile({
    super.key,
    required this.transaction,
    required this.account,
    required this.category,
    required this.categorySourceLabel,
    required this.onTap,
  });

  final BankTransaction transaction;
  final Account? account;
  final SpendCategory? category;
  final String? categorySourceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryColor.forCategoryId(
      category?.id,
      categoryName: category?.name,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: categoryColor),
              Expanded(child: _buildBody(categoryColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color categoryColor) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMerchantAmountRow(),
          const SizedBox(height: AppSpacing.sm),
          _buildCategoryChip(categoryColor),
          if (_hasSecondaryBlock) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 1,
              color: AppColors.borderDepth1.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_hasMetaRow) _buildMetaChips(),
            if (categorySourceLabel != null) ...[
              if (_hasMetaRow) const SizedBox(height: AppSpacing.xs),
              _buildProvenanceLine(),
            ],
            if (_hasNote) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildNoteLine(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMerchantAmountRow() {
    final merchantName = transaction.rawDescription.isEmpty
        ? transaction.normalizedMerchant
        : transaction.rawDescription;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            merchantName,
            style: AppText.body.large.semibold.copyWith(
              color: AppColors.textColor1,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          formatCents(transaction.amountCents),
          style: AppText.body.large.semibold.copyWith(
            color: _amountColor,
            height: 1.25,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(Color categoryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: categoryColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        category?.name ?? 'Uncategorized',
        style: AppText.body.small.semibold.copyWith(
          color: categoryColor,
          fontSize: 12,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildMetaChips() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        if (account != null)
          _MetaChip(label: account!.name, tone: _MetaChipTone.neutral),
        if (transaction.pending)
          const _MetaChip(label: 'Pending', tone: _MetaChipTone.warning),
        if (transaction.excluded)
          const _MetaChip(label: 'Excluded', tone: _MetaChipTone.danger),
        if (transaction.recurringSeries != null)
          const _MetaChip(label: 'Recurring', tone: _MetaChipTone.accent),
      ],
    );
  }

  Widget _buildProvenanceLine() {
    return Text(
      categorySourceLabel!,
      style: AppText.caption.copyWith(
        color: AppColors.accentPrimary.withValues(alpha: 0.9),
        height: 1.25,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNoteLine() {
    return Text(
      transaction.note!.trim(),
      style: AppText.caption.copyWith(
        color: AppColors.textColor4,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  bool get _hasMetaRow =>
      account != null ||
      transaction.pending ||
      transaction.excluded ||
      transaction.recurringSeries != null;

  bool get _hasNote =>
      transaction.note != null && transaction.note!.trim().isNotEmpty;

  bool get _hasSecondaryBlock =>
      _hasMetaRow || categorySourceLabel != null || _hasNote;

  Color get _amountColor {
    if (SpecialCategory.isTransferId(category?.id)) {
      return AppColors.accentSecondary;
    }
    if (transaction.isInflow || SpecialCategory.isIncomeId(category?.id)) {
      return AppColors.success;
    }
    return AppColors.error;
  }
}

enum _MetaChipTone { neutral, warning, danger, accent }

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.tone});

  final String label;
  final _MetaChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color foreground, Color background, Color border) = switch (tone) {
      _MetaChipTone.neutral => (
          AppColors.textColor3,
          AppColors.backgroundDepth5,
          AppColors.borderDepth1,
        ),
      _MetaChipTone.warning => (
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning.withValues(alpha: 0.35),
        ),
      _MetaChipTone.danger => (
          AppColors.error,
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error.withValues(alpha: 0.35),
        ),
      _MetaChipTone.accent => (
          AppColors.accentPrimary,
          AppColors.accentPrimary.withValues(alpha: 0.12),
          AppColors.accentPrimary.withValues(alpha: 0.35),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: foreground,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
