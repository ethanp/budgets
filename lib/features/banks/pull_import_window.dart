/// Time window for transactions first imported during one SimpleFIN pull.
class PullImportWindow {
  const PullImportWindow({
    required this.startedAt,
    this.finishedAt,
  });

  final DateTime startedAt;
  final DateTime? finishedAt;

  @override
  bool operator ==(Object other) =>
      other is PullImportWindow &&
      other.startedAt == startedAt &&
      other.finishedAt == finishedAt;

  @override
  int get hashCode => Object.hash(startedAt, finishedAt);
}
