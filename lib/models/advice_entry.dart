class AdviceEntry {
  const AdviceEntry({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;

  AdviceEntry copyWith({String? text}) => AdviceEntry(
        id: id,
        text: text ?? this.text,
        createdAt: createdAt,
      );

  factory AdviceEntry.fromMap(Map<String, Object?> map) => AdviceEntry(
        id: map['id'] as String,
        text: map['text'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int)),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'text': text,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}
