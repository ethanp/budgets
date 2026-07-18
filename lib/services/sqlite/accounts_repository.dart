import 'package:budgets/domain/account.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:powersync/powersync.dart';

class AccountsRepository {
  AccountsRepository(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<List<Account>> listAccounts() async {
    final rows = await _powerSync.getAll(
      'SELECT * FROM accounts ORDER BY name COLLATE NOCASE',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Account?> findByExternalId(String externalId) async {
    final row = await _powerSync.getOptional(
      'SELECT * FROM accounts WHERE external_id = ? LIMIT 1',
      [externalId],
    );
    if (row == null) return null;
    return _fromRow(row);
  }

  Future<void> upsertAccount(Account account) async {
    final existing = await findByExternalId(account.externalId);
    final id = existing?.id ?? account.id;
    await _powerSync.upsert('accounts', {
      'id': id,
      'external_id': account.externalId,
      'name': account.name,
      'currency': account.currency,
      'balance_cents': account.balanceCents,
      'balance_as_of': account.balanceAsOf?.millisecondsSinceEpoch,
      'conn_id': account.connId,
      'conn_name': account.connName,
      'last_synced_at': account.lastSyncedAt?.millisecondsSinceEpoch,
      'status': account.status.storageValue,
      'status_message': account.statusMessage,
    });
  }

  Future<void> deleteAll() async {
    await _powerSync.execute('DELETE FROM transactions');
    await _powerSync.execute('DELETE FROM accounts');
  }

  static Account _fromRow(dynamic row) {
    return Account(
      id: row['id'] as String,
      externalId: row['external_id'] as String,
      name: row['name'] as String,
      currency: row['currency'] as String,
      balanceCents: _asInt(row['balance_cents']),
      balanceAsOf: _dateFromMillis(_asIntOrNull(row['balance_as_of'])),
      connId: row['conn_id'] as String?,
      connName: row['conn_name'] as String?,
      lastSyncedAt: _dateFromMillis(_asIntOrNull(row['last_synced_at'])),
      status: AccountStatus.fromStorage(row['status'] as String),
      statusMessage: row['status_message'] as String?,
    );
  }

  static DateTime? _dateFromMillis(int? millis) {
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse('$value');
  }

  static int? _asIntOrNull(Object? value) {
    if (value == null) return null;
    return _asInt(value);
  }
}
