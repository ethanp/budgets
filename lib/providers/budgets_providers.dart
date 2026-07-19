import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/budget_month.dart';
import 'package:budgets/domain/categorizer.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
import 'package:budgets/domain/copilot_simplefin_deduper.dart';
import 'package:budgets/domain/life_event.dart';
import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/domain/transaction_ingest.dart';
import 'package:budgets/domain/trend_spend_rate.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:budgets/features/trends/trends_chart_bundle.dart';
import 'package:budgets/services/simplefin/simplefin_access_store.dart';
import 'package:budgets/services/simplefin/simplefin_client.dart';
import 'package:budgets/services/simplefin/simplefin_models.dart';
import 'package:budgets/services/sqlite/accounts_repository.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/chain_stays_repository.dart';
import 'package:budgets/services/sqlite/life_events_repository.dart';
import 'package:budgets/services/sqlite/sync_state_store.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/services/sync/powersync_database_provider.dart';
import 'package:budgets/util/merchant_normalize.dart';
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
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(lifeEventsRepositoryProvider.future);
  return repository.listNewestFirst();
});

final homebaseRepositoryProvider = FutureProvider<ChainStaysRepository>((
  ref,
) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return ChainStaysRepository(database, tableName: 'homebase_stays');
});

final jobRepositoryProvider = FutureProvider<ChainStaysRepository>((ref) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return ChainStaysRepository(database, tableName: 'job_stays');
});

final homebaseChainProvider = FutureProvider<StayChain>((ref) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(homebaseRepositoryProvider.future);
  return repository.loadChain();
});

final jobChainProvider = FutureProvider<StayChain>((ref) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(jobRepositoryProvider.future);
  return repository.loadChain();
});

final syncStateStoreProvider = FutureProvider<SyncStateStore>((ref) async {
  final database = await ref.watch(powerSyncDatabaseProvider.future);
  return SyncStateStore(database);
});

final transactionIngestProvider = FutureProvider<TransactionIngest>((
  ref,
) async {
  return TransactionIngest(
    client: ref.watch(simpleFinClientProvider),
    accessStore: ref.watch(simpleFinAccessStoreProvider),
    accountsRepository: await ref.watch(accountsRepositoryProvider.future),
    transactionsRepository: await ref.watch(
      transactionsRepositoryProvider.future,
    ),
    syncStateStore: await ref.watch(syncStateStoreProvider.future),
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

final copilotSimplefinDeduperProvider =
    FutureProvider<CopilotSimplefinDeduper>((ref) async {
  return CopilotSimplefinDeduper(
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
    syncStateStore: await ref.watch(syncStateStoreProvider.future),
  );
});

final dataRevisionProvider = NotifierProvider<DataRevision, int>(
  DataRevision.new,
);

class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
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
  });

  final bool isConnected;
  final bool fromEnv;
  final List<Account> accounts;
  final List<SimpleFinError> errors;
  final DateTime? lastSyncedAt;
}

final connectionStatusProvider = FutureProvider<ConnectionStatus>((ref) async {
  ref.watch(dataRevisionProvider);
  final accessStore = ref.watch(simpleFinAccessStoreProvider);
  final accountsRepository = await ref.watch(accountsRepositoryProvider.future);
  final syncStateStore = await ref.watch(syncStateStoreProvider.future);
  return ConnectionStatus(
    isConnected: await accessStore.isConnected,
    fromEnv: accessStore.isConfiguredInEnv,
    accounts: await accountsRepository.listAccounts(),
    errors: await syncStateStore.lastErrors(),
    lastSyncedAt: await syncStateStore.lastSuccessfulPullAt(),
  );
});

final transactionsListProvider = FutureProvider<List<BankTransaction>>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(transactionsRepositoryProvider.future);
  return repository.listAll();
});

final accountsMapProvider = FutureProvider<Map<String, Account>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(accountsRepositoryProvider.future);
  final accounts = await repository.listAccounts();
  return {for (final account in accounts) account.id: account};
});

final categoryMonthRowsProvider =
    FutureProvider.family<List<CategoryMonthRow>, String>((
  ref,
  yearMonth,
) async {
  ref.watch(dataRevisionProvider);
  final budgetMonth = await ref.watch(budgetMonthProvider.future);
  return budgetMonth.categoryRows(yearMonth);
});

final categoriesListProvider = FutureProvider<List<SpendCategory>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(categoriesRepositoryProvider.future);
  return repository.listActive();
});

final categoryGroupsProvider = FutureProvider<List<CategoryGroup>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(categoriesRepositoryProvider.future);
  return repository.listGroups();
});

final categorizationRulesProvider =
    FutureProvider<List<CategorizationRule>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(categoriesRepositoryProvider.future);
  return repository.listRules();
});

final currentYearMonthProvider = Provider<String>((ref) {
  return yearMonthKey(DateTime.now());
});

final categoryTrendsProvider = FutureProvider<TrendsChartBundle>((ref) async {
  // Keep across tab switches; rebuilds when [dataRevisionProvider] bumps.
  ref.keepAlive();
  ref.watch(dataRevisionProvider);
  final transactionsRepository =
      await ref.watch(transactionsRepositoryProvider.future);
  final categoriesRepository =
      await ref.watch(categoriesRepositoryProvider.future);
  return const CategoryTrendSeriesFactory().build(
    transactions: await transactionsRepository.listAll(),
    categories: await categoriesRepository.listActive(),
    groups: await categoriesRepository.listGroups(),
  );
});
