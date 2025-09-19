import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_ai/main.dart';
import 'package:food_ai/services/diary_service_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await initializeDateFormatting('ru_RU');
    await DiaryServiceV2.instance.init();
  });

  testWidgets('bottom navigation switches between tabs', (tester) async {
    await tester.pumpWidget(const FoodAiApp());

    expect(find.text('FoodAI'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Поиск'), findsWidgets);

    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    expect(find.text('Мой дневник'), findsWidgets);

    await tester.tap(find.text('Advice'));
    await tester.pumpAndSettle();
    expect(find.text('AI помощник'), findsOneWidget);
  });
}
