/// Life events were renamed from a single `occurred_on` to `started_on` +
/// optional `ended_on` (point / range / ongoing). Postgres renamed the column,
/// but PowerSync keeps schemaless JSON on the client and does **not** rewrite
/// existing keys when a server column is renamed.
///
/// After the rename, local rows could still contain `occurred_on` while the
/// client schema view only exposes `started_on` → null dates → Life Events tab
/// crashed / spun forever on list. This rewrites pending local JSON
/// (`occurred_on` → `started_on`, and fills `ended_on` when missing). Idempotent.
library;

import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';

const _log = ELogger('LifeEvents');

Future<void> migrateLifeEventOccurredOnKeys(PowerSyncDatabase database) async {
  final pendingRows = await database.getAll(r'''
    SELECT COUNT(*) AS c
    FROM ps_data__life_events
    WHERE json_extract(data, '$.occurred_on') IS NOT NULL
      AND json_extract(data, '$.started_on') IS NULL
    ''');
  final pendingCount = pendingRows.isEmpty
      ? 0
      : ((pendingRows.first['c'] as Object?).asIntOrNull() ?? 0);
  if (pendingCount == 0) return;

  await database.execute(r'''
    UPDATE ps_data__life_events
    SET data = json_set(
      json_remove(data, '$.occurred_on'),
      '$.started_on',
      json_extract(data, '$.occurred_on')
    )
    WHERE json_extract(data, '$.occurred_on') IS NOT NULL
      AND json_extract(data, '$.started_on') IS NULL
    ''');

  await database.execute(r'''
    UPDATE ps_data__life_events
    SET data = json_set(
      data,
      '$.ended_on',
      json_extract(data, '$.started_on')
    )
    WHERE json_extract(data, '$.ended_on') IS NULL
      AND json_extract(data, '$.started_on') IS NOT NULL
    ''');

  _log.log('Migrated $pendingCount life event(s): occurred_on → started_on');
}
