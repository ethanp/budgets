import 'package:budgets/data/sqlite/accounts_repository.dart';
import 'package:budgets/data/sqlite/categories_repository.dart';
import 'package:budgets/data/sqlite/sync_state_store.dart';
import 'package:budgets/data/sqlite/transactions_repository.dart';
import 'package:budgets/domain/month_summary.dart';
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

  MonthSummary snapshot(String yearMonth) {
    final accounts = _accountsRepository.listAccounts();
    final names = {
      for (final account in accounts) account.id: account.name,
    };
    return _transactionsRepository.monthSummary(
      yearMonth: yearMonth,
      accountNames: names,
      lastSyncedAt: _syncStateStore.lastSuccessfulPullAt(),
    );
  }

  List<CategoryMonthRow> categoryRows(String yearMonth) {
    final categories = _categoriesRepository.listActive();
    final budgets = {
      for (final budget in _categoriesRepository.budgetsForMonth(yearMonth))
        budget.categoryId: budget.amountCents,
    };
    final spentByCategory = <String, int>{};
    for (final transaction
        in _transactionsRepository.listForMonth(yearMonth)) {
      if (!transaction.isOutflow) continue;
      final categoryId = transaction.effectiveCategoryId;
      if (categoryId == null) continue;
      spentByCategory.update(
        categoryId,
        (value) => value + -transaction.amountCents,
        ifAbsent: () => -transaction.amountCents,
      );
    }

    return categories
        .map(
          (category) => CategoryMonthRow(
            categoryId: category.id,
            categoryName: category.name,
            budgetCents: budgets[category.id] ?? 0,
            spentCents: spentByCategory[category.id] ?? 0,
          ),
        )
        .toList();
  }

  String currentYearMonth() => yearMonthKey(DateTime.now());
}
