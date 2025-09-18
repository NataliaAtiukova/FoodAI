class SearchFoodItem {
  const SearchFoodItem({
    required this.name,
    this.brand,
    this.thumbnailUrl,
  });

  final String name;
  final String? brand;
  final String? thumbnailUrl;

  String get displayName =>
      brand == null || brand!.isEmpty ? name : '$name · $brand';
}
