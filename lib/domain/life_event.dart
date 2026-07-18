class LifeEvent {
  const LifeEvent({
    required this.id,
    required this.title,
    required this.occurredOn,
    this.note,
  });

  final String id;
  final String title;
  final DateTime occurredOn;
  final String? note;
}
