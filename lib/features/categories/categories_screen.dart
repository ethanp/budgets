import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/features/categories/category_editor_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearMonth = ref.watch(currentYearMonthProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final rowsAsync = ref.watch(categoryMonthRowsProvider(yearMonth));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Categories'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => CategoryEditorSheet.show(
            context,
            ref: ref,
            yearMonth: yearMonth,
          ),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return _buildEmptyState(context, ref, yearMonth);
            }
            final rowsById = {
              for (final row in rowsAsync.asData?.value ?? <CategoryMonthRow>[])
                row.categoryId: row,
            };
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: categories.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final category = categories[index];
                final row = rowsById[category.id];
                return _CategoryListTile(
                  category: category,
                  row: row,
                  onTap: () => CategoryEditorSheet.show(
                    context,
                    ref: ref,
                    category: category,
                    yearMonth: yearMonth,
                    currentBudgetCents: row?.budgetCents ?? 0,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    String yearMonth,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No categories yet', style: AppText.headline.small),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add categories to budget and organize spending.',
              style: AppText.body.medium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: () => CategoryEditorSheet.show(
                context,
                ref: ref,
                yearMonth: yearMonth,
              ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: AppText.body.large.semibold),
                  Text(
                    row == null
                        ? 'Tap to edit'
                        : 'Spent ${formatCents(row!.spentCents)}',
                    style: AppText.body.small,
                  ),
                ],
              ),
            ),
            Text(
              row == null || row!.budgetCents == 0
                  ? 'No budget'
                  : formatCents(row!.budgetCents),
              style: AppText.body.medium.semibold,
            ),
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
}
