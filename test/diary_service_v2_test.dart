import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:food_ai/models/diary_entry_v2.dart';
import 'package:food_ai/models/meal_category.dart';
import 'package:food_ai/models/nutrition_models.dart';
import 'package:food_ai/services/app_database.dart';
import 'package:food_ai/services/diary_service_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'foodai_app.db'));
    await AppDatabase.instance.close();
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

    service.resetForTesting();
    await service.init();

    final reloaded = service.getAllEntries();
    expect(reloaded, isNotEmpty);
    expect(reloaded.single.id, entry.id);
    expect(reloaded.single.grams, entry.grams);
  });
}
