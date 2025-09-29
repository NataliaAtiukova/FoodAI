class MealPlanEntry {
  const MealPlanEntry({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String text;
  final DateTime createdAt;

  factory MealPlanEntry.fromMap(Map<String, Object?> map) => MealPlanEntry(
        id: map['id'] as String,
        title: map['title'] as String,
        text: map['text'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int)),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'text': text,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}
