import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/diary_entry.dart';
import '../models/meal_category.dart';

class DiaryService {
  DiaryService._();

  static final DiaryService instance = DiaryService._();
  static const String _entriesBox = 'diary_entries';
  static const String _metaBox = 'diary_meta';
  static const Uuid _uuid = Uuid();

  late Box<DiaryEntry> _entries;
  late Box<dynamic> _meta;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DiaryEntryAdapter());
    }
    _entries = await Hive.openBox<DiaryEntry>(_entriesBox);
    _meta = await Hive.openBox<dynamic>(_metaBox);
    _initialized = true;
  }

  ValueListenable<Box<DiaryEntry>> listenable() {
    _ensureInitialized();
    return _entries.listenable();
  }

  ValueListenable<Box<dynamic>> metaListenable() {
    _ensureInitialized();
    return _meta.listenable();
  }

  Future<DiaryEntry> addEntry({
    required String name,
    required double calories,
    required double protein,
    required double fat,
    required double carbs,
    required String goal,
    required String advice,
    required MealCategory category,
    required String source,
    DateTime? timestamp,
    String? imagePath,
    List<String>? labels,
  }) async {
    _ensureInitialized();
    final entry = DiaryEntry(
      id: _uuid.v4(),
      name: name,
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      goal: goal,
      advice: advice,
      category: category,
      source: source,
      timestamp: timestamp ?? DateTime.now(),
      imagePath: imagePath,
      labels: labels,
    );
    await _entries.put(entry.id, entry);
    return entry;
  }

  List<DiaryEntry> getEntries() {
    _ensureInitialized();
    final entries = _entries.values.toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<void> updateNote(String id, String? note) async {
    _ensureInitialized();
    final entry = _entries.get(id);
    if (entry == null) {
      return;
    }
    entry.note = note;
    await entry.save();
  }

  Future<void> deleteEntry(String id) async {
    _ensureInitialized();
    await _entries.delete(id);
  }

  Map<MealCategory, List<DiaryEntry>> entriesByCategory(DateTime day) {
    _ensureInitialized();
    final normalized = DateTime(day.year, day.month, day.day);
    final Map<MealCategory, List<DiaryEntry>> result = {
      for (final category in MealCategory.values) category: <DiaryEntry>[],
    };

    for (final entry in _entries.values) {
      final entryDay = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (entryDay == normalized) {
        result[entry.category]?.add(entry);
      }
    }

    for (final category in MealCategory.values) {
      result[category]?.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return result;
  }

  DailyTotals? totalsForDay(DateTime day) {
    _ensureInitialized();
    final normalized = DateTime(day.year, day.month, day.day);
    DailyTotals? totals;
    for (final entry in _entries.values) {
      final entryDay = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (entryDay == normalized) {
        totals = (totals ?? DailyTotals.zero()).add(entry);
      }
    }
    return totals;
  }

  Map<DateTime, DailyTotals> totalsByDay() {
    _ensureInitialized();
    final Map<DateTime, DailyTotals> totals = {};
    for (final entry in _entries.values) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      totals.update(
        day,
        (value) => value.add(entry),
        ifAbsent: () => DailyTotals.fromEntry(entry),
      );
    }
    return totals;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('DiaryService.init() must быть вызван до использования.');
    }
  }
}

class DailyTotals {
  DailyTotals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  factory DailyTotals.zero() => DailyTotals(
        calories: 0,
        protein: 0,
        fat: 0,
        carbs: 0,
      );

  factory DailyTotals.fromEntry(DiaryEntry entry) => DailyTotals(
        calories: entry.calories,
        protein: entry.protein,
        fat: entry.fat,
        carbs: entry.carbs,
      );

  DailyTotals add(DiaryEntry entry) => DailyTotals(
        calories: calories + entry.calories,
        protein: protein + entry.protein,
        fat: fat + entry.fat,
        carbs: carbs + entry.carbs,
      );
}
