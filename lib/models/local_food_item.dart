import 'nutrition_models.dart';

class LocalFoodItem {
  const LocalFoodItem({
    required this.id,
    required this.name,
    this.brand,
    required this.factsPer100g,
    this.photoUrl,
    this.barcode,
    this.source,
  });

  final String id;
  final String name;
  final String? brand;
  final NutritionFacts factsPer100g;
  final String? photoUrl;
  final String? barcode;
  final String? source; // 'openfoodfacts', 'manual', 'tflite'

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'brand': brand,
      'facts_per_100g': {
        'calories': factsPer100g.calories,
        'protein': factsPer100g.protein,
        'fat': factsPer100g.fat,
        'carbs': factsPer100g.carbs,
      },
      'photo_url': photoUrl,
      'barcode': barcode,
      'source': source,
    };
  }

  factory LocalFoodItem.fromJson(Map<String, dynamic> json) {
    final factsJson = json['facts_per_100g'] as Map<String, dynamic>;
    final facts = NutritionFacts(
      calories: (factsJson['calories'] as num).toDouble(),
      protein: (factsJson['protein'] as num).toDouble(),
      fat: (factsJson['fat'] as num).toDouble(),
      carbs: (factsJson['carbs'] as num).toDouble(),
    );

    return LocalFoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      factsPer100g: facts,
      photoUrl: json['photo_url'] as String?,
      barcode: json['barcode'] as String?,
      source: json['source'] as String?,
    );
  }

  LocalFoodItem copyWith({
    String? name,
    String? brand,
    NutritionFacts? factsPer100g,
    String? photoUrl,
    String? barcode,
    String? source,
  }) {
    return LocalFoodItem(
      id: id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      factsPer100g: factsPer100g ?? this.factsPer100g,
      photoUrl: photoUrl ?? this.photoUrl,
      barcode: barcode ?? this.barcode,
      source: source ?? this.source,
    );
  }
}
