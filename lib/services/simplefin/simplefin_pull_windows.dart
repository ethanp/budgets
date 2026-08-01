/// SimpleFIN bridge date-window policy (45-day max, overlap for late posts).
class SimpleFinPullWindows {
  SimpleFinPullWindows._();

  /// beta-bridge rejects ranges of 45+ days.
  static const windowDays = 44;
  static const fullHistoryDays = 365 * 2;
  static const incrementalOverlapDays = 2;

  static List<SimpleFinDateWindow> fullHistory(DateTime now) {
    final earliest = now.subtract(const Duration(days: fullHistoryDays));
    final windows = <SimpleFinDateWindow>[];
    var windowEnd = now;
    while (windowEnd.isAfter(earliest)) {
      final windowStart =
          windowEnd.subtract(const Duration(days: windowDays));
      final clampedStart =
          windowStart.isBefore(earliest) ? earliest : windowStart;
      windows.add(SimpleFinDateWindow(start: clampedStart, end: windowEnd));
      windowEnd = clampedStart;
    }
    return windows;
  }

  static SimpleFinDateWindow sinceLastPull({
    required DateTime lastPull,
    required DateTime now,
  }) {
    return SimpleFinDateWindow(
      start: lastPull.subtract(const Duration(days: incrementalOverlapDays)),
      end: now,
    );
  }
}

class SimpleFinDateWindow {
  const SimpleFinDateWindow({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}
