import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:food_ai/main.dart';
import 'package:food_ai/services/ai_history_service.dart';
import 'package:food_ai/services/diary_service_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(fileInput: '');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('ru_RU');
    await DiaryServiceV2.instance.init();
    await AiHistoryService.instance.init();
  });

  testWidgets('bottom navigation switches between tabs', (tester) async {
    await tester.pumpWidget(const FoodAiApp());

    expect(find.text('Сканирование упаковки'), findsWidgets);

    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    expect(find.text('Мой дневник'), findsWidgets);

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('AI помощник'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Сохранённое'), findsOneWidget);
  });
}
