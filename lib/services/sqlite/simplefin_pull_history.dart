import 'dart:convert';

import 'package:spend_trends/services/simplefin/simplefin_models.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:powersync/powersync.dart';

class SimpleFinPullHistory {
  SimpleFinPullHistory(this._powerSync);

  final PowerSyncDatabase _powerSync;

  static const lastSuccessfulPullKey = 'last_successful_pull_at';
  static const lastErrlistKey = 'last_errlist_json';

  Future<DateTime?> lastSuccessfulPullAt() async {
    final value = await _read(lastSuccessfulPullKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> setLastSuccessfulPullAt(DateTime time) async {
    await _write(lastSuccessfulPullKey, time.toIso8601String());
  }

  Future<void> clearLastSuccessfulPullAt() async {
    await _powerSync.execute(
      'DELETE FROM sync_state WHERE key = ?',
      [lastSuccessfulPullKey],
    );
  }

  Future<List<SimpleFinError>> lastErrors() async {
    final value = await _read(lastErrlistKey);
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SimpleFinError.fromJson)
        .toList();
  }

  Future<void> setLastErrors(List<SimpleFinError> errors) async {
    final payload = jsonEncode(
      errors
          .map(
            (error) => {
              'code': error.code,
              'msg': error.message,
              if (error.connId != null) 'conn_id': error.connId,
              if (error.accountId != null) 'account_id': error.accountId,
            },
          )
          .toList(),
    );
    await _write(lastErrlistKey, payload);
  }

  Future<void> clear() async {
    await _powerSync.execute('DELETE FROM sync_state');
  }

  Future<String?> _read(String key) async {
    final row = await _powerSync.getOptional(
      'SELECT value FROM sync_state WHERE key = ? LIMIT 1',
      [key],
    );
    if (row == null) return null;
    return row['value'] as String?;
  }

  Future<void> _write(String key, String value) async {
    // Stable id == key so reinstalls merge on conflictColumns.key.
    await _powerSync.upsert('sync_state', {
      'id': key,
      'key': key,
      'value': value,
    });
  }
}
