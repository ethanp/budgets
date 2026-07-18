import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/month_summary.dart';
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Categories'),
      ),
      child: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (categories) {
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
                return GestureDetector(
                  onTap: () => _editBudget(
                    context,
                    ref,
                    category: category,
                    yearMonth: yearMonth,
                    currentBudgetCents: row?.budgetCents ?? 0,
                  ),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: AppText.body.large.semibold,
                              ),
                              Text(
                                row == null
                                    ? 'Tap to set budget'
                                    : 'Spent ${formatCents(row.spentCents)}',
                                style: AppText.body.small,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          row == null || row.budgetCents == 0
                              ? 'No budget'
                              : formatCents(row.budgetCents),
                          style: AppText.body.medium.semibold,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref, {
    required SpendCategory category,
    required String yearMonth,
    required int currentBudgetCents,
  }) async {
    final controller = TextEditingController(
      text: currentBudgetCents == 0
          ? ''
          : (currentBudgetCents / 100).toStringAsFixed(2),
    );

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
          ),
          decoration: const BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${category.name} budget',
                  style: AppText.headline.small,
                ),
                const SizedBox(height: AppSpacing.md),
                CupertinoTextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: 'Monthly amount',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.md),
                    child: Text('\$'),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  style: AppText.body.large.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                CupertinoButton.filled(
                  onPressed: () async {
                    final dollars = double.tryParse(controller.text.trim()) ?? 0;
                    final repository =
                        await ref.read(categoriesRepositoryProvider.future);
                    await repository.setBudget(
                      categoryId: category.id,
                      yearMonth: yearMonth,
                      amountCents: (dollars * 100).round(),
                    );
                    ref.read(dataRevisionProvider.notifier).bump();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }
}
