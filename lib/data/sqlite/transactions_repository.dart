import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/data/sqlite/budgets_database.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:sqlite3/sqlite3.dart';

class TransactionsRepository {
  TransactionsRepository(this._budgetsDatabase);

  final BudgetsDatabase _budgetsDatabase;

  Database get _database => _budgetsDatabase.database;

  List<BankTransaction> listAll({int? limit}) {
    final sql = StringBuffer(
      'SELECT * FROM transactions ORDER BY posted_at DESC, id DESC',
    );
    if (limit != null) sql.write(' LIMIT $limit');
    return _database.select(sql.toString()).map(_fromRow).toList();
  }

  List<BankTransaction> listForMonth(String yearMonth) {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime(year, month, 1);
    final end = startOfNextMonth(start);
    return _database
        .select(
          '''
          SELECT * FROM transactions
          WHERE posted_at >= ? AND posted_at < ?
          ORDER BY posted_at DESC, id DESC
          ''',
          [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
        )
        .map(_fromRow)
        .toList();
  }

  void upsertTransaction(BankTransaction transaction) {
    _database.execute(
      '''
      INSERT INTO transactions (
        id, account_id, external_id, posted_at, amount_cents,
        raw_description, normalized_merchant, pending,
        user_category_id, suggested_category_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(account_id, external_id) DO UPDATE SET
        posted_at = excluded.posted_at,
        amount_cents = excluded.amount_cents,
        raw_description = excluded.raw_description,
        normalized_merchant = excluded.normalized_merchant,
        pending = excluded.pending
      ''',
      [
        transaction.id,
        transaction.accountId,
        transaction.externalId,
        transaction.postedAt.millisecondsSinceEpoch,
        transaction.amountCents,
        transaction.rawDescription,
        transaction.normalizedMerchant,
        transaction.pending ? 1 : 0,
        transaction.userCategoryId,
        transaction.suggestedCategoryId,
      ],
    );
  }

  void setUserCategory({
    required String transactionId,
    required String? categoryId,
  }) {
    _database.execute(
      'UPDATE transactions SET user_category_id = ? WHERE id = ?',
      [categoryId, transactionId],
    );
  }

  void setSuggestedCategory({
    required String transactionId,
    required String categoryId,
  }) {
    _database.execute(
      '''
      UPDATE transactions
      SET suggested_category_id = ?
      WHERE id = ? AND user_category_id IS NULL
      ''',
      [categoryId, transactionId],
    );
  }

  MonthSummary monthSummary({
    required String yearMonth,
    required Map<String, String> accountNames,
    DateTime? lastSyncedAt,
  }) {
    final transactions = listForMonth(yearMonth);
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

  static BankTransaction _fromRow(Row row) {
    return BankTransaction(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      externalId: row['external_id'] as String,
      postedAt: DateTime.fromMillisecondsSinceEpoch(row['posted_at'] as int),
      amountCents: row['amount_cents'] as int,
      rawDescription: row['raw_description'] as String,
      normalizedMerchant: row['normalized_merchant'] as String,
      pending: (row['pending'] as int) == 1,
      userCategoryId: row['user_category_id'] as String?,
      suggestedCategoryId: row['suggested_category_id'] as String?,
    );
  }
}
