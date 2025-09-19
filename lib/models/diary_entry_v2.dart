import 'meal_category.dart';
import 'nutrition_models.dart';

class DiaryEntryV2 {
  const DiaryEntryV2({
    required this.id,
    required this.name,
    this.brand,
    required this.grams,
    required this.factsPer100g,
    required this.timestamp,
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
  final NutritionFacts factsPer100g;
  final DateTime timestamp;
  final MealCategory category;
  final String source;
  final String? note;
  final String? imagePath;
  final List<String>? labels;

  // Вычисляемые свойства для текущей порции
  NutritionFacts get factsForCurrentServing {
    final multiplier = grams / 100.0;
    return NutritionFacts(
      calories: factsPer100g.calories * multiplier,
      protein: factsPer100g.protein * multiplier,
      fat: factsPer100g.fat * multiplier,
      carbs: factsPer100g.carbs * multiplier,
    );
  }

  DiaryEntryV2 copyWith({
    double? grams,
    String? note,
    MealCategory? category,
  }) {
    return DiaryEntryV2(
      id: id,
      name: name,
      brand: brand,
      grams: grams ?? this.grams,
      factsPer100g: factsPer100g,
      timestamp: timestamp,
      category: category ?? this.category,
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
      'facts_per_100g': {
        'calories': factsPer100g.calories,
        'protein': factsPer100g.protein,
        'fat': factsPer100g.fat,
        'carbs': factsPer100g.carbs,
      },
      'timestamp': timestamp.toIso8601String(),
      'category': category.storageValue,
      'source': source,
      'note': note,
      'image_path': imagePath,
      'labels': labels,
    };
  }

  factory DiaryEntryV2.fromJson(Map<String, dynamic> json) {
    final factsJson = json['facts_per_100g'] as Map<String, dynamic>;
    final facts = NutritionFacts(
      calories: (factsJson['calories'] as num).toDouble(),
      protein: (factsJson['protein'] as num).toDouble(),
      fat: (factsJson['fat'] as num).toDouble(),
      carbs: (factsJson['carbs'] as num).toDouble(),
    );

    return DiaryEntryV2(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      grams: (json['grams'] as num).toDouble(),
      factsPer100g: facts,
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: MealCategoryExt.fromStorage(json['category'] as String?),
      source: json['source'] as String,
      note: json['note'] as String?,
      imagePath: json['image_path'] as String?,
      labels: (json['labels'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}
