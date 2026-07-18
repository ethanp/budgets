import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:powersync/powersync.dart';

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
    final end = startOfNextMonth(start);
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

  Future<void> upsertTransaction(BankTransaction transaction) async {
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
      'user_category_id':
          existing?.userCategoryId ?? transaction.userCategoryId,
      'suggested_category_id':
          existing?.suggestedCategoryId ?? transaction.suggestedCategoryId,
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

  Future<MonthSummary> monthSummary({
    required String yearMonth,
    required Map<String, String> accountNames,
    DateTime? lastSyncedAt,
  }) async {
    final transactions = await listForMonth(yearMonth);
    var outflow = 0;
    var inflow = 0;
    final spentByAccount = <String, int>{};

    for (final transaction in transactions) {
      if (transaction.amountCents < 0) {
        outflow += -transaction.amountCents;
        spentByAccount.update(
          transaction.accountId,
          (value) => value + -transaction.amountCents,
          ifAbsent: () => -transaction.amountCents,
        );
      } else if (transaction.amountCents > 0) {
        inflow += transaction.amountCents;
      }
    }

    final accountSpend = spentByAccount.entries
        .map(
          (entry) => AccountSpendRow(
            accountId: entry.key,
            accountName: accountNames[entry.key] ?? 'Account',
            spentCents: entry.value,
          ),
        )
        .toList()
      ..sort((left, right) => right.spentCents.compareTo(left.spentCents));

    return MonthSummary(
      yearMonth: yearMonth,
      outflowCents: outflow,
      inflowCents: inflow,
      accountSpend: accountSpend,
      lastSyncedAt: lastSyncedAt,
    );
  }

  static BankTransaction _fromRow(dynamic row) {
    return BankTransaction(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      externalId: row['external_id'] as String,
      postedAt: DateTime.fromMillisecondsSinceEpoch(_asInt(row['posted_at'])),
      amountCents: _asInt(row['amount_cents']),
      rawDescription: row['raw_description'] as String,
      normalizedMerchant: row['normalized_merchant'] as String,
      pending: _asInt(row['pending']) == 1,
      userCategoryId: row['user_category_id'] as String?,
      suggestedCategoryId: row['suggested_category_id'] as String?,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse('$value');
  }
}
