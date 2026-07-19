import 'package:ethan_utils/ethan_utils.dart';
import 'package:intl/intl.dart';

class LifeEvent {
  const LifeEvent({
    required this.id,
    required this.title,
    required this.startedOn,
    this.endedOn,
    this.note,
  });

  final String id;
  final String title;
  final DateTime startedOn;

  /// Null = open-ended. Equal to [startedOn] = point-in-time. After = closed range.
  final DateTime? endedOn;
  final String? note;

  bool get isPoint {
    final end = endedOn;
    if (end == null) return false;
    return end.startOfDay == startedOn.startOfDay;
  }

  bool get isOpenEnded => endedOn == null;

  bool get isClosedRange {
    final end = endedOn;
    if (end == null) return false;
    return end.startOfDay.isAfter(startedOn.startOfDay);
  }

  /// End date used for chart clipping (open-ended stretches to [chartMaxDate]).
  DateTime effectiveEndOn(DateTime chartMaxDate) {
    return (endedOn ?? chartMaxDate).startOfDay;
  }

  /// True when the event overlaps the inclusive chart window.
  bool intersectsChart({
    required DateTime chartMinDate,
    required DateTime chartMaxDate,
  }) {
    final start = startedOn.startOfDay;
    final end = effectiveEndOn(chartMaxDate);
    final minDate = chartMinDate.startOfDay;
    final maxDate = chartMaxDate.startOfDay;
    return !start.isAfter(maxDate) && !end.isBefore(minDate);
  }

  String get dateCaption {
    final formatter = DateFormat.yMMMd();
    final startLabel = formatter.format(startedOn);
    if (isPoint) return startLabel;
    if (isOpenEnded) return '$startLabel – present';
    return '$startLabel – ${formatter.format(endedOn!)}';
  }
}
