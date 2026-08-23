import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/app_identity.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/activity/activity_column_widths.dart';
import 'package:spend_trends/features/activity/activity_day_list.dart';
import 'package:spend_trends/features/activity/activity_detail_pane.dart';
import 'package:spend_trends/features/activity/activity_filter_bar.dart';
import 'package:spend_trends/features/activity/activity_visible_transactions.dart';
import 'package:spend_trends/features/activity/manage_rule_sheet.dart';
import 'package:spend_trends/features/activity/recategorize_sheet.dart';
import 'package:spend_trends/features/activity/suggest_categories_sheet.dart';
import 'package:spend_trends/features/banks/banks_controller.dart';
import 'package:spend_trends/features/banks/banks_pull_progress_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/widgets/app_browse_split_shell.dart';
import 'package:spend_trends/widgets/app_card.dart';
import 'package:spend_trends/widgets/sync_status_nav_button.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(
        eyebrow: AppIdentity.displayName,
        title: 'Activity',
        leading: const SyncStatusNavButton(),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => SuggestCategoriesSheet.show(context),
            child: const Text('Suggest categories'),
          ),
          TextButton(
            onPressed: () => refresh(context, ref),
            child: const Text('Pull bank transactions'),
          ),
        ],
      ),
      body: SafeArea(
        child: transactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              '$error',
              style: EText.body.copyWith(color: EColors.danger),
            ),
          ),
          data: (transactions) => _ActivityBody(transactions: transactions),
        ),
      ),
    );
  }

  static Future<void> refresh(BuildContext context, WidgetRef ref) async {
    final connected = await ref.read(simpleFinAccessStoreProvider).isConnected;
    if (!connected) {
      ref.read(spendDataChangedProvider.notifier).notify();
      return;
    }
    if (!context.mounted) return;
    await BanksPullProgressSheet.showAndRun(
      context,
      run: (onProgress) => ref
          .read(banksControllerProvider.notifier)
          .syncLatest(onProgress: onProgress),
    );
  }
}

class _ActivityBody extends ConsumerStatefulWidget {
  const _ActivityBody({required this.transactions});

  final List<BankTransaction> transactions;

  @override
  ConsumerState<_ActivityBody> createState() => _ActivityBodyState();
}

class _ActivityBodyState extends ConsumerState<_ActivityBody> {
  /// Left pane comfort width before the right pane starts growing.
  static const _leftComfortWidth = 1200.0;

  /// After left hits comfort, grow right until 2/3 of that left width.
  static const _rightComfortWidth = _leftComfortWidth * 2 / 3;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _hideRuleMatched = true;
  bool _uncategorizedOnly = false;
  String? _selectedTransactionId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) return _emptyState();

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

    final filtered = ActivityVisibleTransactionsQuery(
      transactions: widget.transactions,
      accounts: accounts,
      categories: categories,
      rules: rules,
      searchQuery: _searchQuery,
      hideRuleMatched: _hideRuleMatched,
      uncategorizedOnly: _uncategorizedOnly,
    ).run();
    final uncategorized = ActivityVisibleTransactionsQuery.uncategorized(
      transactions: widget.transactions,
      accounts: accounts,
    );

    final hasSearch = _searchQuery.trim().isNotEmpty;
    final naturalColumnWidths = ActivityColumnWidths.measure(
      transactions: filtered.visible,
      accounts: accounts,
      categories: categories,
    );
    final selectedTransaction = _transactionById(_selectedTransactionId);

    final isSplit = AppBrowseSplitShell.isSplit(context);

    return AppBrowseSplitShell(
      sizedSide: AppBrowseSplitSizedSide.left,
      initialSizedWidth: _ActivityBodyState._leftComfortWidth,
      growth: const AppBrowseSplitGrowth(
        leftComfortWidth: _ActivityBodyState._leftComfortWidth,
        rightComfortWidth: _ActivityBodyState._rightComfortWidth,
      ),
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivityFilterBar(
            searchController: _searchController,
            onSearchChanged: (query) => setState(() => _searchQuery = query),
            hideRuleMatched: _hideRuleMatched,
            searchMatchCount: filtered.searchMatchCount,
            visibleCount: filtered.visible.length,
            onHideRuleMatchedChanged: (hide) {
              setState(() => _hideRuleMatched = hide);
            },
          ),
          if (!isSplit)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ELayout.spaceLg,
                0,
                ELayout.spaceLg,
                ELayout.spaceSm,
              ),
              child: ActivityVisibleSumBar(
                visibleTransactions: filtered.visible,
              ),
            ),
          Expanded(
            child: _visibleTransactionsScroll(
              filtered: filtered,
              accounts: accounts,
              categories: categories,
              naturalColumnWidths: naturalColumnWidths,
              hasSearch: hasSearch,
            ),
          ),
        ],
      ),
      right: ActivityDetailPane(
        uncategorized: uncategorized,
        visibleTransactions: filtered.visible,
        selected: selectedTransaction,
        uncategorizedOnly: _uncategorizedOnly,
        onUncategorizedFilterApplied: () {
          setState(() {
            _uncategorizedOnly = true;
            _hideRuleMatched = false;
            _selectedTransactionId = null;
          });
        },
        onUncategorizedFilterCleared: () {
          setState(() => _uncategorizedOnly = false);
        },
        onCategorized: () {
          setState(() => _selectedTransactionId = null);
        },
      ),
    );
  }

  /// Width-allocated day list (or empty) inside a pull-to-refresh scroll.
  Widget _visibleTransactionsScroll({
    required ActivityVisibleTransactions filtered,
    required Map<String, Account> accounts,
    required Map<String, SpendCategory> categories,
    required ActivityColumnWidths naturalColumnWidths,
    required bool hasSearch,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidths = naturalColumnWidths.allocate(
          constraints.maxWidth,
        );
        return RefreshIndicator(
          onRefresh: () => ActivityScreen.refresh(context, ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (filtered.visible.isEmpty)
                _noResultsSliver(
                  hasSearch: hasSearch,
                  searchMatchCount: filtered.searchMatchCount,
                )
              else
                ActivityDayListSliver(
                  transactions: filtered.visible,
                  accounts: accounts,
                  categories: categories,
                  ruleMatchIndex: filtered.ruleMatchIndex,
                  explainingByTransactionId:
                      filtered.explainingByTransactionId,
                  selectedTransactionId: _selectedTransactionId,
                  columnWidths: columnWidths,
                  onTransactionSelected: _selectTransaction,
                  onRuleSelected: (rule) => ManageRuleSheet.show(
                    context,
                    ref: ref,
                    rule: rule,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _selectTransaction(BankTransaction transaction) {
    if (!AppBrowseSplitShell.isSplit(context)) {
      RecategorizeSheet.show(context, ref: ref, transaction: transaction);
      return;
    }
    setState(() => _selectedTransactionId = transaction.id);
  }

  BankTransaction? _transactionById(String? id) {
    if (id == null) return null;
    for (final transaction in widget.transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  Widget _noResultsSliver({
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
      padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceLg),
      sliver: SliverToBoxAdapter(
        child: AppCard(child: Text(message, style: EText.body)),
      ),
    );
  }

  Widget _emptyState() {
    final connected =
        ref.watch(connectionStatusProvider).asData?.value.isConnected ?? false;
    return ListView(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      children: [
        AppCard(
          child: Text(
            connected
                ? 'No transactions yet.'
                : 'Connect a bank on the Banks tab to see activity.',
            style: EText.body,
          ),
        ),
      ],
    );
  }
}
