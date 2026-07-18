import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/services/sqlite/accounts_repository.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/sync_state_store.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/util/merchant_normalize.dart';

class BudgetMonth {
  BudgetMonth({
    required AccountsRepository accountsRepository,
    required TransactionsRepository transactionsRepository,
    required CategoriesRepository categoriesRepository,
    required SyncStateStore syncStateStore,
  })  : _accountsRepository = accountsRepository,
        _transactionsRepository = transactionsRepository,
        _categoriesRepository = categoriesRepository,
        _syncStateStore = syncStateStore;

  final AccountsRepository _accountsRepository;
  final TransactionsRepository _transactionsRepository;
  final CategoriesRepository _categoriesRepository;
  final SyncStateStore _syncStateStore;

  Future<MonthSummary> snapshot(String yearMonth) async {
    final accounts = await _accountsRepository.listAccounts();
    final names = {
      for (final account in accounts) account.id: account.name,
    };
    return _transactionsRepository.monthSummary(
      yearMonth: yearMonth,
      accountNames: names,
      lastSyncedAt: await _syncStateStore.lastSuccessfulPullAt(),
    );
  }

  Future<List<CategoryMonthRow>> categoryRows(String yearMonth) async {
    final categories = await _categoriesRepository.listActive();
    final monthOutflows = _outflowByCategory(
      await _transactionsRepository.listForMonth(yearMonth),
    );
    final avg30DayOutflows = _outflowByCategory(
      await _transactionsRepository.listPostedInLastDays(30),
    );

    return categories
        .map(
          (category) => CategoryMonthRow(
            categoryId: category.id,
            categoryName: category.name,
            avg30DaySpendCents: avg30DayOutflows[category.id] ?? 0,
            spentCents: monthOutflows[category.id] ?? 0,
          ),
        )
        .toList();
  }

  String currentYearMonth() => yearMonthKey(DateTime.now());

  static Map<String, int> _outflowByCategory(
    List<BankTransaction> transactions,
  ) {
    final spentByCategory = <String, int>{};
    for (final transaction in transactions) {
      if (transaction.excluded) continue;
      if (!transaction.isOutflow) continue;
      final categoryId = transaction.effectiveCategoryId;
      if (categoryId == null) continue;
      spentByCategory.update(
        categoryId,
        (priorSpendCents) => priorSpendCents + -transaction.amountCents,
        ifAbsent: () => -transaction.amountCents,
      );
    }
    return spentByCategory;
  }
}
