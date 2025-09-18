import 'meal_category.dart';

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.name,
    this.brand,
    required this.grams,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
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
  final double grams;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;
  final DateTime timestamp;
  final String goal;
  final String advice;
  final MealCategory category;
  final String source;
  final String? note;
  final String? imagePath;
  final List<String>? labels;

  double get calories => caloriesPer100g * grams / 100;
  double get protein => proteinPer100g * grams / 100;
  double get fat => fatPer100g * grams / 100;
  double get carbs => carbsPer100g * grams / 100;

  DiaryEntry copyWith({
    double? grams,
    String? note,
    String? advice,
  }) {
    return DiaryEntry(
      id: id,
      name: name,
      brand: brand,
      grams: grams ?? this.grams,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      fatPer100g: fatPer100g,
      carbsPer100g: carbsPer100g,
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
      'grams': grams,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'fat_per_100g': fatPer100g,
      'carbs_per_100g': carbsPer100g,
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
    final storedGrams = _parseDouble(json['grams']);
    final hasNewFormat = storedGrams > 0;
    final fallbackGrams = hasNewFormat ? storedGrams : 100.0;

    double resolvePer100(String key, String legacyKey) {
      if (json.containsKey(key)) {
        return _parseDouble(json[key]);
      }
      final legacy = _parseDouble(json[legacyKey]);
      if (fallbackGrams == 0) {
        return legacy;
      }
      return legacy * 100.0 / fallbackGrams;
    }

    return DiaryEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: (json['brand'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['brand'] as String).trim(),
      grams: fallbackGrams,
      caloriesPer100g: resolvePer100('calories_per_100g', 'calories'),
      proteinPer100g: resolvePer100('protein_per_100g', 'protein'),
      fatPer100g: resolvePer100('fat_per_100g', 'fat'),
      carbsPer100g: resolvePer100('carbs_per_100g', 'carbs'),
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
