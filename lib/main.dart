import 'package:flutter/material.dart';

import 'app_secrets.dart';
import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
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
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeScreen(key: _homeKey),
      DiaryScreen(onAddFood: _onAddFood),
      const SearchScreen(),
      const ProgressScreen(),
    ];

    return MaterialApp(
      title: 'FoodAI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: Colors.white,
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
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
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.book_outlined), label: 'Diary'),
            BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.show_chart_outlined), label: 'Progress'),
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
        return 'Прогресс';
      default:
        return 'FoodAI';
    }
  }

  Future<void> _onAddFood() async {
    if (!mounted) {
      return;
    }

    final action = await showModalBottomSheet<_AddFoodAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Ввести вручную'),
                onTap: () => Navigator.of(context).pop(_AddFoodAction.manual),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Сканировать камерой'),
                onTap: () => Navigator.of(context).pop(_AddFoodAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Выбрать фото'),
                onTap: () => Navigator.of(context).pop(_AddFoodAction.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (action == null) {
      return;
    }

    void switchToHome(VoidCallback? callback) {
      setState(() => _currentIndex = 0);
      if (callback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callback());
      }
    }

    switch (action) {
      case _AddFoodAction.manual:
        switchToHome(null);
        break;
      case _AddFoodAction.camera:
        switchToHome(() => _homeKey.currentState?.startCameraScan());
        break;
      case _AddFoodAction.gallery:
        switchToHome(() => _homeKey.currentState?.startGalleryPick());
        break;
    }
  }
}

enum _AddFoodAction { manual, camera, gallery }
