import 'meal_category.dart';

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.name,
    this.brand,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.timestamp,
    required this.goal,
    required this.advice,
    required this.category,
    required this.source,
    this.note,
    this.imagePath,
    this.labels,
  });

  final String id;
  final String name;
  final String? brand;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final DateTime timestamp;
  final String goal;
  final String advice;
  final MealCategory category;
  final String source;
  final String? note;
  final String? imagePath;
  final List<String>? labels;

  DiaryEntry copyWith({
    String? note,
    String? advice,
  }) {
    return DiaryEntry(
      id: id,
      name: name,
      brand: brand,
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      timestamp: timestamp,
      goal: goal,
      advice: advice ?? this.advice,
      category: category,
      source: source,
      note: note ?? this.note,
      imagePath: imagePath,
      labels: labels == null ? null : List<String>.from(labels!),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'brand': brand,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'timestamp': timestamp.toIso8601String(),
      'goal': goal,
      'advice': advice,
      'category': category.storageValue,
      'source': source,
      'note': note,
      'imagePath': imagePath,
      'labels': labels,
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: (json['brand'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['brand'] as String).trim(),
      calories: _parseDouble(json['calories']),
      protein: _parseDouble(json['protein']),
      fat: _parseDouble(json['fat']),
      carbs: _parseDouble(json['carbs']),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      goal: json['goal'] as String? ?? '',
      advice: json['advice'] as String? ?? '',
      category: MealCategoryExt.fromStorage(json['category'] as String?),
      source: json['source'] as String? ?? 'Home',
      note: json['note'] as String?,
      imagePath: json['imagePath'] as String?,
      labels:
          (json['labels'] as List?)?.map((dynamic e) => e.toString()).toList(),
    );
  }

  static double _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}
