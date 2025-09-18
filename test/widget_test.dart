import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:food_ai/main.dart';
import 'package:food_ai/services/diary_service.dart';

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider() {
    _tempDir = Directory.systemTemp.createTempSync('food_ai_test');
  }

  late final Directory _tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tempDir.path;

  @override
  Future<String?> getApplicationSupportPath() async => _tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => _tempDir.path;

  Future<void> dispose() async {
    if (_tempDir.existsSync()) {
      await _tempDir.delete(recursive: true);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TestPathProvider pathProvider;

  setUpAll(() async {
    pathProvider = _TestPathProvider();
    PathProviderPlatform.instance = pathProvider;
    await initializeDateFormatting('ru_RU');
    await DiaryService.instance.init();
  });

  tearDownAll(() async {
    await pathProvider.dispose();
  });

  testWidgets('bottom navigation switches between tabs', (tester) async {
    await tester.pumpWidget(const FoodAiApp());

    expect(find.text('FoodAI'), findsOneWidget);

    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    expect(find.text('Мой дневник'), findsWidgets);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Прогресс'), findsOneWidget);
  });
}
