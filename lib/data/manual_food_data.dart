import '../models/nutrition_models.dart';

class ManualFood {
  const ManualFood({
    required this.name,
    required this.factsPer100g,
  });

  final String name;
  final NutritionFacts factsPer100g;
}

const Map<String, List<ManualFood>> kManualFoodCategories =
    <String, List<ManualFood>>{
  'Фрукты': <ManualFood>[
    ManualFood(
      name: 'Яблоко',
      factsPer100g:
          NutritionFacts(calories: 52, protein: 0.3, fat: 0.2, carbs: 14),
    ),
    ManualFood(
      name: 'Банан',
      factsPer100g:
          NutritionFacts(calories: 89, protein: 1.1, fat: 0.3, carbs: 23),
    ),
    ManualFood(
      name: 'Апельсин',
      factsPer100g:
          NutritionFacts(calories: 47, protein: 0.9, fat: 0.1, carbs: 12),
    ),
  ],
  'Овощи': <ManualFood>[
    ManualFood(
      name: 'Огурец',
      factsPer100g:
          NutritionFacts(calories: 15, protein: 0.7, fat: 0.1, carbs: 3.6),
    ),
    ManualFood(
      name: 'Помидор',
      factsPer100g:
          NutritionFacts(calories: 18, protein: 0.9, fat: 0.2, carbs: 3.9),
    ),
    ManualFood(
      name: 'Брокколи',
      factsPer100g:
          NutritionFacts(calories: 34, protein: 2.8, fat: 0.4, carbs: 7),
    ),
  ],
  'Мясо и рыба': <ManualFood>[
    ManualFood(
      name: 'Куриная грудка',
      factsPer100g:
          NutritionFacts(calories: 165, protein: 31, fat: 3.6, carbs: 0),
    ),
    ManualFood(
      name: 'Говядина постная',
      factsPer100g:
          NutritionFacts(calories: 187, protein: 23, fat: 10, carbs: 0),
    ),
    ManualFood(
      name: 'Лосось',
      factsPer100g:
          NutritionFacts(calories: 208, protein: 20, fat: 13, carbs: 0),
    ),
  ],
  'Хлеб и крупы': <ManualFood>[
    ManualFood(
      name: 'Гречка варёная',
      factsPer100g:
          NutritionFacts(calories: 110, protein: 3.6, fat: 1.3, carbs: 21.3),
    ),
    ManualFood(
      name: 'Рис белый варёный',
      factsPer100g:
          NutritionFacts(calories: 130, protein: 2.7, fat: 0.3, carbs: 28),
    ),
    ManualFood(
      name: 'Хлеб цельнозерновой',
      factsPer100g:
          NutritionFacts(calories: 247, protein: 13, fat: 4.2, carbs: 41),
    ),
  ],
  'Напитки': <ManualFood>[
    ManualFood(
      name: 'Кофе с молоком (без сахара)',
      factsPer100g:
          NutritionFacts(calories: 40, protein: 2, fat: 1.5, carbs: 4.5),
    ),
    ManualFood(
      name: 'Апельсиновый сок',
      factsPer100g:
          NutritionFacts(calories: 45, protein: 0.7, fat: 0.2, carbs: 10.4),
    ),
    ManualFood(
      name: 'Зелёный смузи',
      factsPer100g:
          NutritionFacts(calories: 60, protein: 2.5, fat: 1.2, carbs: 11),
    ),
  ],
};
