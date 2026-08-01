import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/budget_month.dart';
import 'package:spend_trends/domain/categorizer.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/domain/remove_copilot_duplicates.dart';
import 'package:spend_trends/domain/life_event.dart';
import 'package:spend_trends/domain/month_summary.dart';
import 'package:spend_trends/domain/stay_chain.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/domain/pull_simplefin_transactions.dart';
import 'package:spend_trends/domain/trend_spend_rate.dart';
import 'package:spend_trends/features/trends/build_trends_charts.dart';
import 'package:spend_trends/features/trends/trends_chart_bundle.dart';
import 'package:spend_trends/services/simplefin/simplefin_access_store.dart';
import 'package:spend_trends/services/simplefin/simplefin_client.dart';
import 'package:spend_trends/services/simplefin/simplefin_models.dart';
import 'package:spend_trends/services/sqlite/accounts_repository.dart';
import 'package:spend_trends/services/sqlite/categories_repository.dart';
import 'package:spend_trends/services/sqlite/chain_stays_repository.dart';
import 'package:spend_trends/services/sqlite/life_events_repository.dart';
import 'package:spend_trends/services/sqlite/simplefin_pull_history.dart';
import 'package:spend_trends/services/sqlite/transactions_repository.dart';
import 'package:spend_trends/services/sync/powersync_database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final simpleFinClientProvider = Provider<SimpleFinClient>((ref) {
  final client = SimpleFinClient();
  ref.onDispose(client.close);
  return client;
});

final simpleFinAccessStoreProvider = Provider<SimpleFinAccessStore>((ref) {
  return SimpleFinAccessStore();
});

final accountsRepositoryProvider = FutureProvider<AccountsRepository>((
  ref,
) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return AccountsRepository(database);
});

final transactionsRepositoryProvider = FutureProvider<TransactionsRepository>((
  ref,
) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return TransactionsRepository(database);
});

final categoriesRepositoryProvider = FutureProvider<CategoriesRepository>((
  ref,
) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return CategoriesRepository(database);
});

final lifeEventsRepositoryProvider = FutureProvider<LifeEventsRepository>((
  ref,
) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return LifeEventsRepository(database);
});

final lifeEventsProvider = FutureProvider<List<LifeEvent>>((ref) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(lifeEventsRepositoryProvider.future);
  return repository.listNewestFirst();
});

final housingStaysRepositoryProvider = FutureProvider<ChainStaysRepository>((
  ref,
) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return ChainStaysRepository(database, tableName: 'housing_stays');
});

final jobStaysRepositoryProvider = FutureProvider<ChainStaysRepository>((ref) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return ChainStaysRepository(database, tableName: 'job_stays');
});

final housingChainProvider = FutureProvider<StayChain>((ref) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(housingStaysRepositoryProvider.future);
  return repository.loadChain();
});

final jobChainProvider = FutureProvider<StayChain>((ref) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(jobStaysRepositoryProvider.future);
  return repository.loadChain();
});

final simpleFinPullHistoryProvider = FutureProvider<SimpleFinPullHistory>((
  ref,
) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return SimpleFinPullHistory(database);
});

final pullSimpleFinTransactionsProvider =
    FutureProvider<PullSimpleFinTransactions>((ref) async {
  return PullSimpleFinTransactions(
    client: ref.watch(simpleFinClientProvider),
    accessStore: ref.watch(simpleFinAccessStoreProvider),
    accountsRepository: await ref.watch(accountsRepositoryProvider.future),
    transactionsRepository: await ref.watch(
      transactionsRepositoryProvider.future,
    ),
    simpleFinPullHistory: await ref.watch(simpleFinPullHistoryProvider.future),
  );
});

final categorizerProvider = FutureProvider<Categorizer>((ref) async {
  return Categorizer(
    categoriesRepository: await ref.watch(categoriesRepositoryProvider.future),
    transactionsRepository: await ref.watch(
      transactionsRepositoryProvider.future,
    ),
    accountsRepository: await ref.watch(accountsRepositoryProvider.future),
  );
});

final removeCopilotDuplicatesProvider =
    FutureProvider<RemoveCopilotDuplicates>((ref) async {
  return RemoveCopilotDuplicates(
    accountsRepository: await ref.watch(accountsRepositoryProvider.future),
    transactionsRepository: await ref.watch(
      transactionsRepositoryProvider.future,
    ),
  );
});

final budgetMonthProvider = FutureProvider<BudgetMonth>((ref) async {
  return BudgetMonth(
    accountsRepository: await ref.watch(accountsRepositoryProvider.future),
    transactionsRepository: await ref.watch(
      transactionsRepositoryProvider.future,
    ),
    categoriesRepository: await ref.watch(categoriesRepositoryProvider.future),
    simpleFinPullHistory: await ref.watch(simpleFinPullHistoryProvider.future),
  );
});

final spendDataChangedProvider = NotifierProvider<SpendDataChanged, int>(
  SpendDataChanged.new,
);

class SpendDataChanged extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state = state + 1;
}

/// Shared yr/mo/day display rate for both Trends charts.
final trendSpendRateProvider =
    NotifierProvider<TrendSpendRateNotifier, TrendSpendRate>(
  TrendSpendRateNotifier.new,
);

class TrendSpendRateNotifier extends Notifier<TrendSpendRate> {
  @override
  TrendSpendRate build() => TrendSpendRate.perYear;

  void setRate(TrendSpendRate rate) => state = rate;
}

class ConnectionStatus {
  const ConnectionStatus({
    required this.isConnected,
    required this.fromEnv,
    required this.accounts,
    required this.errors,
    this.lastSyncedAt,
    this.latestFinishedPull,
    this.latestRunningPull,
  });

  final bool isConnected;
  final bool fromEnv;
  final List<Account> accounts;
  final List<SimpleFinError> errors;
  final DateTime? lastSyncedAt;
  final SimpleFinPullRecord? latestFinishedPull;
  final SimpleFinPullRecord? latestRunningPull;
}

final connectionStatusProvider = FutureProvider<ConnectionStatus>((ref) async {
  ref.watch(spendDataChangedProvider);
  final accessStore = ref.watch(simpleFinAccessStoreProvider);
  final accountsRepository = await ref.watch(accountsRepositoryProvider.future);
  final simpleFinPullHistory =
      await ref.watch(simpleFinPullHistoryProvider.future);
  return ConnectionStatus(
    isConnected: await accessStore.isConnected,
    fromEnv: accessStore.isConfiguredInEnv,
    accounts: await accountsRepository.listAccounts(),
    errors: await simpleFinPullHistory.lastErrors(),
    lastSyncedAt: await simpleFinPullHistory.lastSuccessfulPullAt(),
    latestFinishedPull: await simpleFinPullHistory.latestFinished(),
    latestRunningPull: await simpleFinPullHistory.latestRunning(),
  );
});

final simpleFinPullHistoryListProvider =
    FutureProvider<List<SimpleFinPullRecord>>((ref) async {
  ref.watch(spendDataChangedProvider);
  final history = await ref.watch(simpleFinPullHistoryProvider.future);
  return history.listRecent();
});

final transactionsListProvider = FutureProvider<List<BankTransaction>>((
  ref,
) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(transactionsRepositoryProvider.future);
  return repository.listAll();
});

final accountsMapProvider = FutureProvider<Map<String, Account>>((ref) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(accountsRepositoryProvider.future);
  final accounts = await repository.listAccounts();
  return {for (final account in accounts) account.id: account};
});

final categoryMonthRowsProvider =
    FutureProvider.family<List<CategoryMonthRow>, String>((
  ref,
  yearMonth,
) async {
  ref.watch(spendDataChangedProvider);
  final budgetMonth = await ref.watch(budgetMonthProvider.future);
  return budgetMonth.categoryRows(yearMonth);
});

final categoriesListProvider = FutureProvider<List<SpendCategory>>((ref) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(categoriesRepositoryProvider.future);
  return repository.listActive();
});

final categoryGroupsProvider = FutureProvider<List<CategoryGroup>>((ref) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(categoriesRepositoryProvider.future);
  return repository.listGroups();
});

final categorizationRulesProvider =
    FutureProvider<List<CategorizationRule>>((ref) async {
  ref.watch(spendDataChangedProvider);
  final repository = await ref.watch(categoriesRepositoryProvider.future);
  return repository.listRules();
});

final currentYearMonthProvider = Provider<String>((ref) {
  return DateTime.now().yearMonthKey;
});

final trendsChartBundleProvider = FutureProvider<TrendsChartBundle>((ref) async {
  // Keep across tab switches; rebuilds when [spendDataChangedProvider] notifies.
  ref.keepAlive();
  ref.watch(spendDataChangedProvider);
  final transactionsRepository =
      await ref.watch(transactionsRepositoryProvider.future);
  final categoriesRepository =
      await ref.watch(categoriesRepositoryProvider.future);
  final accountsRepository =
      await ref.watch(accountsRepositoryProvider.future);
  return const BuildTrendsCharts().build(
    transactions: await transactionsRepository.listAll(),
    categories: await categoriesRepository.listActive(),
    groups: await categoriesRepository.listGroups(),
    accounts: await accountsRepository.listAccounts(),
  );
});
