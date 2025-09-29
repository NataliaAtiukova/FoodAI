import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'screens/ai_assistant_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'services/ai_history_service.dart';
import 'services/diary_service_v2.dart';
import 'services/local_food_database_service.dart';

const Color _brandGreen = Color(0xFF2A825A);

const NavigationDestinationLabelBehavior _labelBehavior =
    NavigationDestinationLabelBehavior.alwaysShow;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env may be absent in CI/production; fall back to --dart-define only
  }

  // Инициализируем локальные сервисы
  await DiaryServiceV2.instance.init();
  await AiHistoryService.instance.init();
  await LocalFoodDatabaseService.instance.initialize();
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
    final pages = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const DiaryScreen(),
      const AiAssistantScreen(),
      const SavedScreen(),
    ];
    final clampedIndex = _currentIndex.clamp(0, pages.length - 1).toInt();

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandGreen,
          brightness: Brightness.light,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: _brandGreen.withValues(alpha: 0.12),
          labelBehavior: _labelBehavior,
        ),
      ),
      home: Scaffold(
        body: IndexedStack(
          index: clampedIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: clampedIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: _EmojiIcon('🏠'),
              selectedIcon: _EmojiIcon('🏠', selected: true),
              label: 'Home',
            ),
            NavigationDestination(
              icon: _EmojiIcon('🔍'),
              selectedIcon: _EmojiIcon('🔍', selected: true),
              label: 'Search',
            ),
            NavigationDestination(
              icon: _EmojiIcon('📒'),
              selectedIcon: _EmojiIcon('📒', selected: true),
              label: 'Diary',
            ),
            NavigationDestination(
              icon: _EmojiIcon('🤖'),
              selectedIcon: _EmojiIcon('🤖', selected: true),
              label: 'AI',
            ),
            NavigationDestination(
              icon: _EmojiIcon('⭐'),
              selectedIcon: _EmojiIcon('⭐', selected: true),
              label: 'Saved',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiIcon extends StatelessWidget {
  const _EmojiIcon(this.emoji, {this.selected = false});

  final String emoji;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Text(
      emoji,
      style: TextStyle(
        fontSize: 20,
        color: color,
      ),
    );
  }
}
