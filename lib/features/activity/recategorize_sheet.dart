import 'package:budgets/domain/transaction.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecategorizeSheet extends ConsumerStatefulWidget {
  const RecategorizeSheet({super.key, required this.transaction});

  final BankTransaction transaction;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required BankTransaction transaction,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => RecategorizeSheet(transaction: transaction),
    );
  }

  @override
  ConsumerState<RecategorizeSheet> createState() => _RecategorizeSheetState();
}

class _RecategorizeSheetState extends ConsumerState<RecategorizeSheet> {
  bool _createRule = true;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: categoriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (categories) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Categorize', style: AppText.headline.small),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.transaction.normalizedMerchant,
                        style: AppText.body.small,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          CupertinoSwitch(
                            value: _createRule,
                            onChanged: (value) =>
                                setState(() => _createRule = value),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Always for this merchant',
                              style: AppText.body.medium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        onPressed: () => _assign(category.id),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            category.name,
                            style: AppText.body.large,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _assign(String categoryId) async {
    final categorizer = await ref.read(categorizerProvider.future);
    categorizer.assignUserCategory(
      transactionId: widget.transaction.id,
      categoryId: categoryId,
      merchantPattern: widget.transaction.normalizedMerchant,
      createRule: _createRule,
    );
    categorizer.applyRulesToUncategorized();
    ref.read(dataRevisionProvider.notifier).bump();
    if (mounted) Navigator.of(context).pop();
  }
}
