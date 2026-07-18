import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/categorizer.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/activity/activity_search.dart';
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

class _ActivityBody extends ConsumerStatefulWidget {
  const _ActivityBody({required this.transactions});

  final List<BankTransaction> transactions;

  @override
  ConsumerState<_ActivityBody> createState() => _ActivityBodyState();
}

class _ActivityBodyState extends ConsumerState<_ActivityBody> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _hideRuleMatched = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) return _buildEmptyState();

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

    final hasSearch = _searchQuery.trim().isNotEmpty;
    final searchMatches = [
      for (final transaction in widget.transactions)
        if (activityMatchesSearch(
          transaction: transaction,
          query: _searchQuery,
          account: accounts[transaction.accountId],
          category: categories[transaction.effectiveCategoryId],
        ))
          transaction,
    ];
    final visibleTransactions = _hideRuleMatched
        ? [
            for (final transaction in searchMatches)
              if (Categorizer.explainingRule(transaction, rules) == null)
                transaction,
          ]
        : searchMatches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStickySearchAndFilter(
          searchMatchCount: searchMatches.length,
          visibleCount: visibleTransactions.length,
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () => ActivityScreen._refresh(ref),
              ),
              if (visibleTransactions.isEmpty)
                _buildNoResultsSliver(
                  hasSearch: hasSearch,
                  searchMatchCount: searchMatches.length,
                )
              else
                _buildTransactionListSliver(
                  visibleTransactions: visibleTransactions,
                  accounts: accounts,
                  categories: categories,
                  rules: rules,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickySearchAndFilter({
    required int searchMatchCount,
    required int visibleCount,
  }) {
    return ColoredBox(
      color: AppColors.backgroundDepth1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search description, category, account…',
              onChanged: (query) => setState(() => _searchQuery = query),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RuleMatchFilterToggle(
              hideRuleMatched: _hideRuleMatched,
              hiddenCount: searchMatchCount - visibleCount,
              visibleCount: visibleCount,
              onChanged: (hideRuleMatched) {
                setState(() => _hideRuleMatched = hideRuleMatched);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsSliver({
    required bool hasSearch,
    required int searchMatchCount,
  }) {
    final message = hasSearch && searchMatchCount == 0
        ? 'No transactions match this search.'
        : hasSearch
            ? 'No unmatched transactions for this search. '
                'Turn off “Hide rule-matched” to see more.'
            : 'All loaded transactions match a rule. '
                'Turn off the filter to see them.';
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      sliver: SliverToBoxAdapter(
        child: AppCard(
          child: Text(message, style: AppText.body.medium),
        ),
      ),
    );
  }

  Widget _buildTransactionListSliver({
    required List<BankTransaction> visibleTransactions,
    required Map<String, Account> accounts,
    required Map<String, SpendCategory> categories,
    required List<CategorizationRule> rules,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      sliver: SliverList.separated(
        itemCount: visibleTransactions.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final transaction = visibleTransactions[index];
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
    );
  }

  Widget _buildEmptyState() {
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
}

class _RuleMatchFilterToggle extends StatelessWidget {
  const _RuleMatchFilterToggle({
    required this.hideRuleMatched,
    required this.hiddenCount,
    required this.visibleCount,
    required this.onChanged,
  });

  final bool hideRuleMatched;
  final int hiddenCount;
  final int visibleCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hide rule-matched',
                  style: AppText.body.medium.semibold,
                ),
                Text(
                  hideRuleMatched
                      ? '$visibleCount shown · $hiddenCount hidden'
                      : 'Showing all loaded transactions',
                  style: AppText.body.small,
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: hideRuleMatched,
            onChanged: onChanged,
          ),
        ],
      ),
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
    return [
      if (account != null) account!.name,
      DateFormat.MMMd().format(transaction.postedAt.toLocal()),
      if (transaction.pending) 'Pending',
      if (transaction.excluded) 'Excluded',
      if (transaction.recurringSeries != null)
        'Recurring: ${transaction.recurringSeries}',
      category?.name ?? 'Uncategorized',
      if (transaction.note != null && transaction.note!.isNotEmpty)
        transaction.note!,
    ];
  }
}
