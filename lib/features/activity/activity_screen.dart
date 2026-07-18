import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/categorizer.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/activity/recategorize_sheet.dart';
import 'package:budgets/features/activity/suggest_categories_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsListProvider);
    final accountsAsync = ref.watch(accountsMapProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final rulesAsync = ref.watch(categorizationRulesProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Activity'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => SuggestCategoriesSheet.show(context),
              child: const Icon(CupertinoIcons.sparkles),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _refresh(ref),
              child: const Icon(CupertinoIcons.refresh),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: transactionsAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (transactions) {
            if (transactions.isEmpty) {
              final connected =
                  connectionAsync.asData?.value.isConnected ?? false;
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    child: Text(
                      connected
                          ? 'No transactions yet. Pull to refresh.'
                          : 'Connect a bank in Settings to see activity.',
                      style: AppText.body.medium,
                    ),
                  ),
                ],
              );
            }

            final accounts = accountsAsync.asData?.value ?? {};
            final categories = {
              for (final category
                  in categoriesAsync.asData?.value ?? <SpendCategory>[])
                category.id: category,
            };
            final rules = rulesAsync.asData?.value ?? const <CategorizationRule>[];

            return CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () => _refresh(ref),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  sliver: SliverList.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final matchedRule = Categorizer.explainingRule(
                        transaction,
                        rules,
                      );
                      return _TransactionRow(
                        transaction: transaction,
                        account: accounts[transaction.accountId],
                        category: categories[transaction.effectiveCategoryId],
                        matchedRule: matchedRule,
                        onTap: () => RecategorizeSheet.show(
                          context,
                          ref: ref,
                          transaction: transaction,
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

  Future<void> _refresh(WidgetRef ref) async {
    final connected =
        await ref.read(simpleFinAccessStoreProvider).isConnected;
    if (!connected) {
      ref.read(dataRevisionProvider.notifier).bump();
      return;
    }
    final ingest = await ref.read(transactionIngestProvider.future);
    await ingest.pullAndUpsert();
    final categorizer = await ref.read(categorizerProvider.future);
    await categorizer.applyRulesToUncategorized();
    ref.read(dataRevisionProvider.notifier).bump();
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.account,
    required this.category,
    required this.matchedRule,
    required this.onTap,
  });

  final BankTransaction transaction;
  final Account? account;
  final SpendCategory? category;
  final CategorizationRule? matchedRule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountStyle = transaction.isOutflow
        ? AppText.body.medium.primary.semibold
        : AppText.body.medium.success.semibold;

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
                  Text(
                    transaction.rawDescription.isEmpty
                        ? transaction.normalizedMerchant
                        : transaction.rawDescription,
                    style: AppText.body.large.semibold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _subtitleParts.join(' · '),
                    style: AppText.body.small,
                  ),
                  if (matchedRule != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Rule: contains “${matchedRule!.pattern}”',
                      style: AppText.body.small.copyWith(
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(formatCents(transaction.amountCents), style: amountStyle),
          ],
        ),
      ),
    );
  }

  List<String> get _subtitleParts {
    return [
      if (account != null) account!.name,
      DateFormat.MMMd().format(transaction.postedAt.toLocal()),
      if (transaction.pending) 'Pending',
      category?.name ?? 'Uncategorized',
    ];
  }
}
