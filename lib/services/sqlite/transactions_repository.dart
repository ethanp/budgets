import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';

class _MonthFlowTotals {
  const _MonthFlowTotals({
    required this.outflowCents,
    required this.inflowCents,
    required this.spentByAccount,
  });

  final int outflowCents;
  final int inflowCents;
  final Map<String, int> spentByAccount;
}

class TransactionsRepository {
  TransactionsRepository(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<List<BankTransaction>> listAll({int? limit}) async {
    final sql = StringBuffer(
      'SELECT * FROM transactions ORDER BY posted_at DESC, id DESC',
    );
    if (limit != null) sql.write(' LIMIT $limit');
    final rows = await _powerSync.getAll(sql.toString());
    return rows.map(_fromRow).toList();
  }

  Future<List<BankTransaction>> listForMonth(String yearMonth) async {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime(year, month, 1);
    return listPostedBetween(start, startOfNextMonth(start));
  }

  /// Inclusive of [start], exclusive of [end], by `posted_at`.
  Future<List<BankTransaction>> listPostedBetween(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _powerSync.getAll(
      '''
      SELECT * FROM transactions
      WHERE posted_at >= ? AND posted_at < ?
      ORDER BY posted_at DESC, id DESC
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return rows.map(_fromRow).toList();
  }

  /// Rolling window ending now: `[now - days, now)`.
  Future<List<BankTransaction>> listPostedInLastDays(int days) {
    final end = DateTime.now();
    return listPostedBetween(end.subtract(Duration(days: days)), end);
  }

  Future<BankTransaction?> findByAccountExternalId({
    required String accountId,
    required String externalId,
  }) async {
    final row = await _powerSync.getOptional(
      '''
      SELECT * FROM transactions
      WHERE account_id = ? AND external_id = ?
      LIMIT 1
      ''',
      [accountId, externalId],
    );
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Keys are `accountId|externalId` for O(1) resume/skip checks.
  Future<Set<String>> existingAccountExternalKeys() async {
    final rows = await _powerSync.getAll(
      'SELECT account_id, external_id FROM transactions',
    );
    return {
      for (final row in rows)
        '${row['account_id'] as String}|${row['external_id'] as String}',
    };
  }

  Future<void> upsertTransaction(
    BankTransaction transaction, {
    bool overwriteUserCategory = false,
  }) async {
    final existing = await findByAccountExternalId(
      accountId: transaction.accountId,
      externalId: transaction.externalId,
    );
    final id = existing?.id ?? transaction.id;
    await _powerSync.upsert('transactions', {
      'id': id,
      'account_id': transaction.accountId,
      'external_id': transaction.externalId,
      'posted_at': transaction.postedAt.millisecondsSinceEpoch,
      'amount_cents': transaction.amountCents,
      'raw_description': transaction.rawDescription,
      'normalized_merchant': transaction.normalizedMerchant,
      'pending': transaction.pending ? 1 : 0,
      'user_category_id': overwriteUserCategory
          ? transaction.userCategoryId
          : (existing?.userCategoryId ?? transaction.userCategoryId),
      'suggested_category_id': overwriteUserCategory
          ? transaction.suggestedCategoryId
          : (existing?.suggestedCategoryId ?? transaction.suggestedCategoryId),
      'note': transaction.note,
      'transaction_type': transaction.transactionType,
      'excluded': transaction.excluded ? 1 : 0,
      'recurring_series': transaction.recurringSeries,
      'imported_at': (existing?.importedAt ?? transaction.importedAt)
          ?.millisecondsSinceEpoch,
    });
  }

  Future<void> setUserCategory({
    required String transactionId,
    required String? categoryId,
  }) async {
    await _powerSync.execute(
      'UPDATE transactions SET user_category_id = ? WHERE id = ?',
      [categoryId, transactionId],
    );
  }

  Future<void> setSuggestedCategory({
    required String transactionId,
    required String categoryId,
  }) async {
    await _powerSync.execute(
      '''
      UPDATE transactions
      SET suggested_category_id = ?
      WHERE id = ? AND user_category_id IS NULL
      ''',
      [categoryId, transactionId],
    );
  }

  /// Move a locked user category onto suggested so default rules can own it.
  Future<void> releaseUserCategoryToSuggested({
    required String transactionId,
    required String categoryId,
  }) async {
    await _powerSync.execute(
      '''
      UPDATE transactions
      SET user_category_id = NULL, suggested_category_id = ?
      WHERE id = ?
      ''',
      [categoryId, transactionId],
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _powerSync.execute(
      'DELETE FROM transactions WHERE id = ?',
      [transactionId],
    );
  }

  Future<MonthSummary> monthSummary({
    required String yearMonth,
    required Map<String, String> accountNames,
    DateTime? lastSyncedAt,
  }) async {
    final transactions = await listForMonth(yearMonth);
    final flows = _aggregateMonthFlows(transactions);

    return MonthSummary(
      yearMonth: yearMonth,
      outflowCents: flows.outflowCents,
      inflowCents: flows.inflowCents,
      accountSpend: _sortedAccountSpendRows(
        spentByAccount: flows.spentByAccount,
        accountNames: accountNames,
      ),
      lastSyncedAt: lastSyncedAt,
    );
  }

  _MonthFlowTotals _aggregateMonthFlows(List<BankTransaction> transactions) {
    var outflowCents = 0;
    var inflowCents = 0;
    final spentByAccount = <String, int>{};

    for (final transaction in transactions) {
      if (transaction.excluded) continue;
      if (transaction.amountCents < 0) {
        outflowCents += -transaction.amountCents;
        spentByAccount.update(
          transaction.accountId,
          (value) => value + -transaction.amountCents,
          ifAbsent: () => -transaction.amountCents,
        );
      } else if (transaction.amountCents > 0) {
        inflowCents += transaction.amountCents;
      }
    }

    return _MonthFlowTotals(
      outflowCents: outflowCents,
      inflowCents: inflowCents,
      spentByAccount: spentByAccount,
    );
  }

  List<AccountSpendRow> _sortedAccountSpendRows({
    required Map<String, int> spentByAccount,
    required Map<String, String> accountNames,
  }) {
    return spentByAccount.entries
        .map(
          (entry) => AccountSpendRow(
            accountId: entry.key,
            accountName: accountNames[entry.key] ?? 'Account',
            spentCents: entry.value,
          ),
        )
        .toList()
      ..sort((left, right) => right.spentCents.compareTo(left.spentCents));
  }

  static BankTransaction _fromRow(dynamic row) {
    final columns = (row as Map).cast<String, Object?>();
    return BankTransaction(
      id: columns['id'] as String,
      accountId: columns['account_id'] as String,
      externalId: columns['external_id'] as String,
      postedAt: columns['posted_at'].asInt().dateTimeFromMillis,
      amountCents: columns['amount_cents'].asInt(),
      rawDescription: columns['raw_description'] as String,
      normalizedMerchant: columns['normalized_merchant'] as String,
      pending: columns['pending'].asInt() == 1,
      userCategoryId: columns['user_category_id'] as String?,
      suggestedCategoryId: columns['suggested_category_id'] as String?,
      note: columns['note'] as String?,
      transactionType: columns['transaction_type'] as String?,
      excluded:
          columns['excluded'] != null && columns['excluded'].asInt() == 1,
      recurringSeries: columns['recurring_series'] as String?,
      importedAt: columns['imported_at'].asIntOrNull().dateTimeFromMillis,
    );
  }
}
