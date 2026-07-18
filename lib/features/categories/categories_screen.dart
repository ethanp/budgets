import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/features/categories/category_editor_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String yearMonth = ref.watch(currentYearMonthProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final rowsAsync = ref.watch(categoryMonthRowsProvider(yearMonth));

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, ref),
      child: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (categories) => _categoriesContent(
            context,
            ref,
            categories,
            rowsAsync,
          ),
        ),
      ),
    );
  }

  CupertinoNavigationBar _navigationBar(
    BuildContext context,
    WidgetRef ref,
  ) {
    return CupertinoNavigationBar(
      leading: const SyncStatusNavButton(),
      middle: const Text('Categories'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => CategoryEditorSheet.show(context, ref: ref),
        child: const Icon(CupertinoIcons.add),
      ),
    );
  }

  Widget _categoriesContent(
    BuildContext context,
    WidgetRef ref,
    List<SpendCategory> categories,
    AsyncValue<List<CategoryMonthRow>> rowsAsync,
  ) {
    if (categories.isEmpty) {
      return _buildEmptyState(context, ref);
    }
    return _categoryList(context, ref, categories, rowsAsync);
  }

  Widget _categoryList(
    BuildContext context,
    WidgetRef ref,
    List<SpendCategory> categories,
    AsyncValue<List<CategoryMonthRow>> rowsAsync,
  ) {
    final rowsById = {
      for (final row in rowsAsync.asData?.value ?? <CategoryMonthRow>[])
        row.categoryId: row,
    };
    final spendCategories = [
      for (final category in categories)
        if (!SpecialCategory.isSpecialId(category.id)) category,
    ];
    final specialCategories = [
      for (final category in categories)
        if (SpecialCategory.isSpecialId(category.id)) category,
    ];
    final listedCategories = [...spendCategories, ...specialCategories];
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: listedCategories.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final category = listedCategories[index];
        final row = rowsById[category.id];
        return _CategoryListTile(
          category: category,
          row: row,
          onTap: () => CategoryEditorSheet.show(
            context,
            ref: ref,
            category: category,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No categories yet', style: AppText.headline.small),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add categories to organize spending.',
              style: AppText.body.medium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: () => CategoryEditorSheet.show(context, ref: ref),
              child: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryListTile extends StatelessWidget {
  const _CategoryListTile({
    required this.category,
    required this.row,
    required this.onTap,
  });

  final SpendCategory category;
  final CategoryMonthRow? row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: _categoryDetails()),
            _annualPaceLabel(),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textColor4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryDetails() {
    final isSpecial = SpecialCategory.isSpecialId(category.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(category.name, style: AppText.body.large.semibold),
        Text(
          isSpecial
              ? 'Built-in · cash flow'
              : row == null
                  ? 'Tap to edit'
                  : 'This month ${formatCents(row!.spentCents)}',
          style: AppText.body.small,
        ),
      ],
    );
  }

  Widget _annualPaceLabel() {
    if (SpecialCategory.isSpecialId(category.id)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          row == null || row!.annualizedSpendCents == 0
              ? '—'
              : formatCents(row!.annualizedSpendCents),
          style: AppText.body.medium.semibold,
        ),
        Text('/ yr', style: AppText.body.small),
      ],
    );
  }
}
