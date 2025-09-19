import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_ai/services/diary_service_v2.dart';
import 'package:food_ai/models/diary_entry_v2.dart';
import 'package:food_ai/models/meal_category.dart';
import 'package:food_ai/models/nutrition_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DiaryServiceV2.instance.resetForTesting();
  });

  test('persists entries across init calls', () async {
    final service = DiaryServiceV2.instance;

    await service.init();
    expect(service.getAllEntries(), isEmpty);

    final entry = DiaryEntryV2(
      id: 'test-1',
      name: 'Test food',
      grams: 150,
      factsPer100g: const NutritionFacts(
        calories: 200,
        protein: 15,
        fat: 10,
        carbs: 25,
      ),
      timestamp: DateTime(2024, 1, 1, 12),
      category: MealCategory.dinner,
      source: 'test',
    );

    await service.addEntry(entry);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('diary_entries_v2');
    expect(stored, isNotNull);

    service.resetForTesting();
    await service.init();

    final reloaded = service.getAllEntries();
    expect(reloaded, isNotEmpty);
    expect(reloaded.single.id, entry.id);
    expect(reloaded.single.grams, entry.grams);
  });
}
