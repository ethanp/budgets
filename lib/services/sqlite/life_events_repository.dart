import 'package:budgets/domain/life_event.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

class LifeEventsRepository {
  LifeEventsRepository(this._powerSync);

  final PowerSyncDatabase _powerSync;
  final _uuid = const Uuid();

  Future<List<LifeEvent>> listNewestFirst() async {
    final rows = await _powerSync.getAll(
      '''
      SELECT * FROM life_events
      ORDER BY occurred_on DESC, title COLLATE NOCASE
      ''',
    );
    return rows.map(_fromRow).toList();
  }

  Future<LifeEvent> create({
    required String title,
    required DateTime occurredOn,
    String? note,
  }) async {
    final event = LifeEvent(
      id: _uuid.v4(),
      title: title.trim(),
      occurredOn: occurredOn.startOfDay,
      note: _normalizedNote(note),
    );
    await upsert(event);
    return event;
  }

  Future<void> upsert(LifeEvent event) async {
    final trimmedTitle = event.title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Title is required.');
    }
    await _powerSync.upsert('life_events', {
      'id': event.id,
      'title': trimmedTitle,
      'occurred_on': event.occurredOn.startOfDay.millisecondsSinceEpoch,
      'note': _normalizedNote(event.note),
    });
  }

  Future<void> delete(String eventId) async {
    await _powerSync.execute(
      'DELETE FROM life_events WHERE id = ?',
      [eventId],
    );
  }

  static String? _normalizedNote(String? note) {
    final trimmed = note?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static LifeEvent _fromRow(dynamic row) {
    return LifeEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      occurredOn: DateTime.fromMillisecondsSinceEpoch(
        _asInt(row['occurred_on']),
      ).startOfDay,
      note: row['note'] as String?,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse('$value');
  }
}
