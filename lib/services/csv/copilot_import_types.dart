class CopilotImportResult {
  const CopilotImportResult({
    required this.transactionCount,
    required this.accountCount,
    required this.skippedRows,
    required this.alreadyPresentCount,
    this.notesFilledCount = 0,
    this.simplefinMatchSkipCount = 0,
    this.cancelled = false,
  });

  final int transactionCount;
  final int accountCount;
  final int skippedRows;
  final int alreadyPresentCount;
  final int notesFilledCount;

  /// CSV rows skipped because a linked SimpleFIN charge already exists.
  final int simplefinMatchSkipCount;
  final bool cancelled;
}

class CopilotImportProgress {
  const CopilotImportProgress({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  double get fraction => total <= 0 ? 0 : completed / total;
}

/// Cooperative cancel flag for a single Copilot CSV import run.
class CopilotImportCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

class CopilotImportCancelledException implements Exception {
  @override
  String toString() => 'Copilot import cancelled.';
}
