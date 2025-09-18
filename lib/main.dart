import 'package:flutter/material.dart';

import 'app_secrets.dart';
import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_product_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/search_screen.dart';
import 'services/diary_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureEnvLoaded();
  await DiaryService.instance.init();
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
      HomeScreen(onNavigateToTab: _setCurrentIndex),
      const DiaryScreen(),
      const SearchScreen(),
      const MyProductScreen(),
      const ProgressScreen(),
    ];

    return MaterialApp(
      title: 'FoodAI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: Colors.white,
        snackBarTheme:
            const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(_titleForIndex(_currentIndex)),
          centerTitle: true,
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.book_outlined), label: 'Diary'),
            BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined), label: 'Search'),
            BottomNavigationBarItem(
                icon: Icon(Icons.edit_outlined), label: 'Мой продукт'),
            BottomNavigationBarItem(
                icon: Icon(Icons.show_chart_outlined), label: 'Progress'),
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
        return 'Поиск';
      case 3:
        return 'Мой продукт';
      case 4:
        return 'Прогресс';
      default:
        return 'FoodAI';
    }
  }

  void _setCurrentIndex(int index) {
    setState(() => _currentIndex = index);
  }
}
