import 'package:budgets/domain/account.dart';
import 'package:budgets/data/sqlite/budgets_database.dart';
import 'package:sqlite3/sqlite3.dart';

class AccountsRepository {
  AccountsRepository(this._budgetsDatabase);

  final BudgetsDatabase _budgetsDatabase;

  Database get _database => _budgetsDatabase.database;

  List<Account> listAccounts() {
    final rows = _database.select(
      'SELECT * FROM accounts ORDER BY name COLLATE NOCASE',
    );
    return rows.map(_fromRow).toList();
  }

  Account? findByExternalId(String externalId) {
    final rows = _database.select(
      'SELECT * FROM accounts WHERE external_id = ? LIMIT 1',
      [externalId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  void upsertAccount(Account account) {
    _database.execute(
      '''
      INSERT INTO accounts (
        id, external_id, name, currency, balance_cents, balance_as_of,
        conn_id, conn_name, last_synced_at, status, status_message
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(external_id) DO UPDATE SET
        name = excluded.name,
        currency = excluded.currency,
        balance_cents = excluded.balance_cents,
        balance_as_of = excluded.balance_as_of,
        conn_id = excluded.conn_id,
        conn_name = excluded.conn_name,
        last_synced_at = excluded.last_synced_at,
        status = excluded.status,
        status_message = excluded.status_message
      ''',
      [
        account.id,
        account.externalId,
        account.name,
        account.currency,
        account.balanceCents,
        account.balanceAsOf?.millisecondsSinceEpoch,
        account.connId,
        account.connName,
        account.lastSyncedAt?.millisecondsSinceEpoch,
        account.status.storageValue,
        account.statusMessage,
      ],
    );
  }

  void deleteAll() {
    _database.execute('DELETE FROM transactions');
    _database.execute('DELETE FROM accounts');
  }

  static Account _fromRow(Row row) {
    return Account(
      id: row['id'] as String,
      externalId: row['external_id'] as String,
      name: row['name'] as String,
      currency: row['currency'] as String,
      balanceCents: row['balance_cents'] as int,
      balanceAsOf: _dateFromMillis(row['balance_as_of'] as int?),
      connId: row['conn_id'] as String?,
      connName: row['conn_name'] as String?,
      lastSyncedAt: _dateFromMillis(row['last_synced_at'] as int?),
      status: AccountStatus.fromStorage(row['status'] as String),
      statusMessage: row['status_message'] as String?,
    );
  }

  static DateTime? _dateFromMillis(int? millis) {
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
