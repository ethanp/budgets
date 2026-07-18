import 'dart:convert';

import 'package:budgets/data/simplefin/simplefin_models.dart';
import 'package:budgets/data/sqlite/budgets_database.dart';

class SyncStateStore {
  SyncStateStore(this._budgetsDatabase);

  final BudgetsDatabase _budgetsDatabase;

  static const lastSuccessfulPullKey = 'last_successful_pull_at';
  static const lastErrlistKey = 'last_errlist_json';

  DateTime? lastSuccessfulPullAt() {
    final value = _read(lastSuccessfulPullKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  void setLastSuccessfulPullAt(DateTime time) {
    _write(lastSuccessfulPullKey, time.toIso8601String());
  }

  List<SimpleFinError> lastErrors() {
    final value = _read(lastErrlistKey);
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SimpleFinError.fromJson)
        .toList();
  }

  void setLastErrors(List<SimpleFinError> errors) {
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
    _write(lastErrlistKey, payload);
  }

  void clear() {
    _budgetsDatabase.database.execute('DELETE FROM sync_state');
  }

  String? _read(String key) {
    final rows = _budgetsDatabase.database.select(
      'SELECT value FROM sync_state WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void _write(String key, String value) {
    _budgetsDatabase.database.execute(
      '''
      INSERT INTO sync_state (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
  }
}
