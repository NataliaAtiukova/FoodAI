import 'nutrition_models.dart';

class SearchFoodItem {
  const SearchFoodItem({
    required this.name,
    this.brand,
    this.thumbnailUrl,
    this.factsPer100g,
  });

  final String name;
  final String? brand;
  final String? thumbnailUrl;
  final NutritionFacts? factsPer100g;

  String get displayName =>
      brand == null || brand!.isEmpty ? name : '$name · $brand';
}
