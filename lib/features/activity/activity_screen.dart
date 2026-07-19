import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/categorizer.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/activity/activity_search.dart';
import 'package:budgets/features/activity/activity_transaction_tile.dart';
import 'package:budgets/features/activity/recategorize_sheet.dart';
import 'package:budgets/features/activity/suggest_categories_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:ethan_utils/ethan_utils.dart';
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
  bool _showVisibleSum = false;

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
    final ruleMatchIndex = RuleMatchIndex(rules);
    final Map<String, CategorizationRule?> explainingByTransactionId;
    final List<BankTransaction> visibleTransactions;
    if (_hideRuleMatched) {
      // Full scan only when filtering — prepared rules are reused across txns.
      explainingByTransactionId =
          ruleMatchIndex.explainingRulesByTransactionId(searchMatches);
      visibleTransactions = [
        for (final transaction in searchMatches)
          if (!_isAutoCategorized(
            transaction,
            explainingByTransactionId[transaction.id],
          ))
            transaction,
      ];
    } else {
      explainingByTransactionId = const {};
      visibleTransactions = searchMatches;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStickySearchAndFilter(
          searchMatchCount: searchMatches.length,
          visibleTransactions: visibleTransactions,
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
                  ruleMatchIndex: ruleMatchIndex,
                  explainingByTransactionId: explainingByTransactionId,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// True when a real rule explains the category, or Copilot/suggested filled it.
  bool _isAutoCategorized(
    BankTransaction transaction,
    CategorizationRule? explainingRule,
  ) {
    if (explainingRule != null) {
      // Ignore leftover priority-0 import rules — those are not real rules.
      if (explainingRule.priority > CategorizationRule.defaultImportPriority) {
        return true;
      }
    }
    return transaction.userCategoryId == null &&
        transaction.suggestedCategoryId != null;
  }

  Widget _buildStickySearchAndFilter({
    required int searchMatchCount,
    required List<BankTransaction> visibleTransactions,
  }) {
    final visibleCount = visibleTransactions.length;
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
            VSpace.sm,
            _RuleMatchFilterToggle(
              hideRuleMatched: _hideRuleMatched,
              hiddenCount: searchMatchCount - visibleCount,
              visibleCount: visibleCount,
              onChanged: (hideRuleMatched) {
                setState(() => _hideRuleMatched = hideRuleMatched);
              },
            ),
            VSpace.sm,
            _VisibleSumBar(
              visibleTransactions: visibleTransactions,
              showSum: _showVisibleSum,
              onToggle: visibleCount == 0
                  ? null
                  : () => setState(() => _showVisibleSum = !_showVisibleSum),
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
                'Turn off “Hide auto-categorized” to see more.'
            : 'All loaded transactions are already categorized. '
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
    required RuleMatchIndex ruleMatchIndex,
    required Map<String, CategorizationRule?> explainingByTransactionId,
  }) {
    final listItems = _dayGroupedListItems(visibleTransactions);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final listItem = listItems[index];
            if (listItem is _ActivityDayHeader) {
              return _ActivityDayHeaderTile(
                label: listItem.label,
                isFirst: index == 0,
              );
            }
            final transaction = (listItem as _ActivityTransactionItem).transaction;
            final account = accounts[transaction.accountId];
            final category = categories[transaction.effectiveCategoryId];
            final explainingRule = explainingByTransactionId[transaction.id] ??
                ruleMatchIndex.explainingRule(transaction);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ActivityTransactionTile(
                transaction: transaction,
                account: account,
                category: category,
                categorySourceLabel: _categorySourceLabel(
                  transaction: transaction,
                  account: account,
                  category: category,
                  explainingRule: explainingRule,
                ),
                onTap: () => RecategorizeSheet.show(
                  context,
                  ref: ref,
                  transaction: transaction,
                ),
              ),
            );
          },
          childCount: listItems.length,
        ),
      ),
    );
  }

  String? _categorySourceLabel({
    required BankTransaction transaction,
    required Account? account,
    required SpendCategory? category,
    required CategorizationRule? explainingRule,
  }) {
    if (explainingRule != null &&
        explainingRule.priority > CategorizationRule.defaultImportPriority) {
      return 'Rule: contains “${explainingRule.pattern}”';
    }

    final categoryName = category?.name;
    if (categoryName == null || categoryName.isEmpty) return null;
    if (transaction.userCategoryId != null) return null;
    if (transaction.suggestedCategoryId == null) return null;
    if (transaction.suggestedCategoryId != transaction.effectiveCategoryId) {
      return null;
    }

    final isCopilotAccount =
        account?.externalId.startsWith('copilot:') ?? false;
    if (isCopilotAccount) {
      return 'Copilot category was “$categoryName”';
    }
    return 'Suggested: $categoryName';
  }

  List<_ActivityListItem> _dayGroupedListItems(
    List<BankTransaction> transactions,
  ) {
    final today = DateTime.now().startOfDay;
    final yesterday = today.subtract(const Duration(days: 1));
    final listItems = <_ActivityListItem>[];
    DateTime? currentDay;

    for (final transaction in transactions) {
      final day = transaction.postedAt.toLocal().startOfDay;
      if (currentDay != day) {
        currentDay = day;
        listItems.add(
          _ActivityDayHeader(label: _dayHeaderLabel(day, today, yesterday)),
        );
      }
      listItems.add(_ActivityTransactionItem(transaction: transaction));
    }
    return listItems;
  }

  String _dayHeaderLabel(DateTime day, DateTime today, DateTime yesterday) {
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    if (day.year == today.year) {
      return DateFormat('EEEE, MMM d').format(day);
    }
    return DateFormat('EEEE, MMM d, y').format(day);
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
                  'Hide auto-categorized',
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

class _VisibleSumBar extends StatelessWidget {
  const _VisibleSumBar({
    required this.visibleTransactions,
    required this.showSum,
    required this.onToggle,
  });

  final List<BankTransaction> visibleTransactions;
  final bool showSum;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sum visible list',
                  style: AppText.body.medium.semibold,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                onPressed: onToggle,
                child: Text(showSum ? 'Hide' : 'Sum'),
              ),
            ],
          ),
          if (showSum && visibleTransactions.isNotEmpty) ...[
            VSpace.xs,
            _buildSumDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildSumDetails() {
    var netCents = 0;
    var inflowCents = 0;
    var outflowCents = 0;
    for (final transaction in visibleTransactions) {
      netCents += transaction.amountCents;
      if (transaction.isInflow) {
        inflowCents += transaction.amountCents;
      } else if (transaction.isOutflow) {
        outflowCents += transaction.amountCents;
      }
    }

    final netColor = netCents > 0
        ? AppColors.success
        : netCents < 0
            ? AppColors.error
            : AppColors.textBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${visibleTransactions.length} '
              '${visibleTransactions.length == 1 ? 'transaction' : 'transactions'}',
              style: AppText.body.small,
            ),
            const Spacer(),
            Text(
              formatCents(netCents),
              style: AppText.body.large.semibold.copyWith(color: netColor),
            ),
          ],
        ),
        if (inflowCents != 0 || outflowCents != 0) ...[
          VSpace.xs,
          Text(
            'In ${formatCents(inflowCents)} · Out ${formatCents(outflowCents)}',
            style: AppText.caption,
            textAlign: TextAlign.end,
          ),
        ],
      ],
    );
  }
}

class _ActivityDayHeaderTile extends StatelessWidget {
  const _ActivityDayHeaderTile({
    required this.label,
    required this.isFirst,
  });

  final String label;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? AppSpacing.xs : AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.body.medium.semibold.copyWith(
              color: AppColors.textBody,
              letterSpacing: 0.2,
            ),
          ),
          HSpace.md,
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.borderDepth1,
            ),
          ),
        ],
      ),
    );
  }
}

sealed class _ActivityListItem {
  const _ActivityListItem();
}

class _ActivityDayHeader extends _ActivityListItem {
  const _ActivityDayHeader({required this.label});

  final String label;
}

class _ActivityTransactionItem extends _ActivityListItem {
  const _ActivityTransactionItem({required this.transaction});

  final BankTransaction transaction;
}
