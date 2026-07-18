import 'package:budgets/application/budget_month.dart';
import 'package:budgets/application/categorizer.dart';
import 'package:budgets/application/transaction_ingest.dart';
import 'package:budgets/data/simplefin/simplefin_access_store.dart';
import 'package:budgets/data/simplefin/simplefin_client.dart';
import 'package:budgets/data/simplefin/simplefin_models.dart';
import 'package:budgets/data/sqlite/accounts_repository.dart';
import 'package:budgets/data/sqlite/budgets_database.dart';
import 'package:budgets/data/sqlite/categories_repository.dart';
import 'package:budgets/data/sqlite/sync_state_store.dart';
import 'package:budgets/data/sqlite/transactions_repository.dart';
import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final budgetsDatabaseProvider = FutureProvider<BudgetsDatabase>((ref) async {
  final database = await BudgetsDatabase.open();
  ref.onDispose(database.close);
  return database;
});

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
  final database = await ref.watch(budgetsDatabaseProvider.future);
  return AccountsRepository(database);
});

final transactionsRepositoryProvider = FutureProvider<TransactionsRepository>((
  ref,
) async {
  final database = await ref.watch(budgetsDatabaseProvider.future);
  return TransactionsRepository(database);
});

final categoriesRepositoryProvider = FutureProvider<CategoriesRepository>((
  ref,
) async {
  final database = await ref.watch(budgetsDatabaseProvider.future);
  return CategoriesRepository(database);
});

final syncStateStoreProvider = FutureProvider<SyncStateStore>((ref) async {
  final database = await ref.watch(budgetsDatabaseProvider.future);
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
    accounts: accountsRepository.listAccounts(),
    errors: syncStateStore.lastErrors(),
    lastSyncedAt: syncStateStore.lastSuccessfulPullAt(),
  );
});

final transactionsListProvider = FutureProvider<List<BankTransaction>>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(transactionsRepositoryProvider.future);
  return repository.listAll(limit: 500);
});

final accountsMapProvider = FutureProvider<Map<String, Account>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repository = await ref.watch(accountsRepositoryProvider.future);
  final accounts = repository.listAccounts();
  return {for (final account in accounts) account.id: account};
});

final monthSummaryProvider = FutureProvider.family<MonthSummary, String>((
  ref,
  yearMonth,
) async {
  ref.watch(dataRevisionProvider);
  final budgetMonth = await ref.watch(budgetMonthProvider.future);
  return budgetMonth.snapshot(yearMonth);
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

final currentYearMonthProvider = Provider<String>((ref) {
  return yearMonthKey(DateTime.now());
});
