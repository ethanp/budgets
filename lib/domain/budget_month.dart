import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/centered_year_pace.dart';
import 'package:budgets/features/trends/trend_chart_catalog.dart';
import 'package:budgets/services/sqlite/accounts_repository.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/sync_state_store.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:ethan_utils/ethan_utils.dart';

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
    final trailingYearOutflows = _outflowByCategory(
      await _transactionsRepository.listPostedInLastDays(
        CenteredYearPace.rollingDays,
      ),
    );
    final observedDays = _observedTrailingDays();

    return [
      for (final category in categories)
        if (!SpecialCategory.isFlowId(category.id))
          CategoryMonthRow(
            categoryId: category.id,
            categoryName: category.name,
            annualizedSpendCents: CenteredYearPace
                .annualizePartialWindow(
                  windowTotalCents:
                      (trailingYearOutflows[category.id] ?? 0).toDouble(),
                  observedDays: observedDays,
                )
                .round(),
            spentCents: monthOutflows[category.id] ?? 0,
          ),
    ];
  }

  /// Calendar days on or after [chartHistoryStart] inside the trailing window.
  static int _observedTrailingDays() {
    final today = DateTime.now().startOfDay;
    final historyFloor =
        TrendChartCatalog.chartHistoryStart.startOfDay;
    final windowFloor = today.shiftedByDays(
      -(CenteredYearPace.rollingDays - 1),
    );
    final effectiveFloor =
        windowFloor.isBefore(historyFloor) ? historyFloor : windowFloor;
    final observedDays = today.difference(effectiveFloor).inDays + 1;
    if (observedDays < 1) return 1;
    if (observedDays > CenteredYearPace.rollingDays) {
      return CenteredYearPace.rollingDays;
    }
    return observedDays;
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
