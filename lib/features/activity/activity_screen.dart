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
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsListProvider);

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, ref),
      child: SafeArea(
        child: transactionsAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (transactions) => _ActivityBody(transactions: transactions),
        ),
      ),
    );
  }

  CupertinoNavigationBar _navigationBar(BuildContext context, WidgetRef ref) {
    return CupertinoNavigationBar(
      leading: const SyncStatusNavButton(),
      middle: const Text('Activity'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            onPressed: () => SuggestCategoriesSheet.show(context),
            child: const Text('Suggest categories'),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            onPressed: () => _refresh(ref),
            child: const Text('Sync bank'),
          ),
        ],
      ),
    );
  }

  static Future<void> _refresh(WidgetRef ref) async {
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

class _ActivityBody extends ConsumerWidget {
  const _ActivityBody({required this.transactions});

  final List<BankTransaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) return _buildEmptyState(ref);

    final accounts = ref.watch(accountsMapProvider).asData?.value ?? {};
    final categories = {
      for (final category
          in ref.watch(categoriesListProvider).asData?.value ??
              <SpendCategory>[])
        category.id: category,
    };
    final rules =
        ref.watch(categorizationRulesProvider).asData?.value ??
            const <CategorizationRule>[];

    return _buildTransactionList(ref, accounts, categories, rules);
  }

  Widget _buildEmptyState(WidgetRef ref) {
    final connected =
        ref.watch(connectionStatusProvider).asData?.value.isConnected ?? false;
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

  Widget _buildTransactionList(
    WidgetRef ref,
    Map<String, Account> accounts,
    Map<String, SpendCategory> categories,
    List<CategorizationRule> rules,
  ) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => ActivityScreen._refresh(ref),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: transactions.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return _TransactionRow(
                transaction: transaction,
                account: accounts[transaction.accountId],
                category: categories[transaction.effectiveCategoryId],
                matchedRule: Categorizer.explainingRule(transaction, rules),
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
            Expanded(child: _buildLeadingDetails()),
            const SizedBox(width: AppSpacing.md),
            Text(formatCents(transaction.amountCents), style: amountStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingDetails() {
    return Column(
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
        Text(_subtitleParts.join(' · '), style: AppText.body.small),
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
    );
  }

  List<String> get _subtitleParts {
    final transactionType = transaction.transactionType?.trim();
    return [
      if (account != null) account!.name,
      DateFormat.MMMd().format(transaction.postedAt.toLocal()),
      if (transaction.pending) 'Pending',
      if (transaction.excluded) 'Excluded',
      if (transactionType != null &&
          transactionType.isNotEmpty &&
          transactionType.toLowerCase() != 'regular')
        transactionType,
      if (transaction.recurringSeries != null)
        'Recurring: ${transaction.recurringSeries}',
      category?.name ?? 'Uncategorized',
      if (transaction.note != null && transaction.note!.isNotEmpty)
        transaction.note!,
    ];
  }
}
