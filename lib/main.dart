import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/advice_screen.dart';
import 'screens/progress_screen.dart';
import 'services/diary_service_v2.dart';
import 'services/local_food_database_service.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем локальные сервисы
  await DiaryServiceV2.instance.init();
  await LocalFoodDatabaseService.instance.initialize();
  await ProgressService.instance.init();
  await initializeDateFormatting('ru');
  Intl.defaultLocale = 'ru';

  runApp(const FoodAiApp());
}

class FoodAiApp extends StatefulWidget {
  const FoodAiApp({super.key});

  @override
  State<FoodAiApp> createState() => _FoodAiAppState();
}

class _FoodAiAppState extends State<FoodAiApp> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const HomeScreen(),
      const DiaryScreen(),
      const AdviceScreen(),
      const ProgressScreen(),
    ];
    final int currentIndex = _currentIndex.clamp(0, tabs.length - 1).toInt();

    return MaterialApp(
      title: 'FoodAI',
      locale: const Locale('ru'),
      supportedLocales: const <Locale>[
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: Colors.white,
        snackBarTheme:
            const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(_titleForIndex(currentIndex)),
          centerTitle: true,
        ),
        body: IndexedStack(
          index: currentIndex,
          children: tabs,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              label: 'Diary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb_outline),
              label: 'Advice',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'FoodAI';
      case 1:
        return 'Мой дневник';
      case 2:
        return 'Советы';
      case 3:
        return 'Прогресс';
      default:
        return 'FoodAI';
    }
  }
}
