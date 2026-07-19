import 'package:budgets/domain/account.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
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
    final columns = (row as Map).cast<String, Object?>();
    return Account(
      id: columns['id'] as String,
      externalId: columns['external_id'] as String,
      name: columns['name'] as String,
      currency: columns['currency'] as String,
      balanceCents: columns['balance_cents'].asInt(),
      balanceAsOf: columns['balance_as_of'].asIntOrNull().dateTimeFromMillis,
      connId: columns['conn_id'] as String?,
      connName: columns['conn_name'] as String?,
      lastSyncedAt:
          columns['last_synced_at'].asIntOrNull().dateTimeFromMillis,
      status: AccountStatus.fromStorage(columns['status'] as String),
      statusMessage: columns['status_message'] as String?,
    );
  }
}
