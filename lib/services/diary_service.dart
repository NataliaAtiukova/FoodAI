import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/diary_entry.dart';
import '../models/meal_category.dart';

class DiaryService {
  DiaryService._();

  static final DiaryService instance = DiaryService._();
  static const String _storageKey = 'diary_entries_v1';
  static const Uuid _uuid = Uuid();

  final ValueNotifier<List<DiaryEntry>> _entriesNotifier =
      ValueNotifier<List<DiaryEntry>>(<DiaryEntry>[]);

  SharedPreferences? _preferences;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final entries = decoded
            .map((dynamic item) =>
                DiaryEntry.fromJson(item as Map<String, dynamic>))
            .toList();
        entries.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        );
        _entriesNotifier.value = List<DiaryEntry>.unmodifiable(entries);
      } catch (_) {
        _entriesNotifier.value = const <DiaryEntry>[];
      }
    }

    _initialized = true;
  }

  ValueListenable<List<DiaryEntry>> listenable() {
    _ensureInitialized();
    return _entriesNotifier;
  }

  List<DiaryEntry> getEntries() {
    _ensureInitialized();
    return _entriesNotifier.value;
  }

  Future<DiaryEntry> addEntry({
    required String name,
    String? brand,
    required double grams,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double fatPer100g,
    required double carbsPer100g,
    required String goal,
    required String advice,
    required MealCategory category,
    required String source,
    DateTime? timestamp,
    String? imagePath,
    List<String>? labels,
  }) async {
    _ensureInitialized();

    final safeGrams = grams <= 0 ? 100.0 : grams;

    final entry = DiaryEntry(
      id: _uuid.v4(),
      name: name,
      brand: brand,
      grams: safeGrams,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      fatPer100g: fatPer100g,
      carbsPer100g: carbsPer100g,
      timestamp: timestamp ?? DateTime.now(),
      goal: goal,
      advice: advice,
      category: category,
      source: source,
      note: null,
      imagePath: imagePath,
      labels: labels,
    );

    final entries = List<DiaryEntry>.from(_entriesNotifier.value)..add(entry);
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _setEntries(entries);
    return entry;
  }

  Future<void> updateNote(String id, String? note) async {
    _ensureInitialized();
    final entries = _entriesNotifier.value
        .map((entry) => entry.id == id ? entry.copyWith(note: note) : entry)
        .toList();
    await _setEntries(entries);
  }

  Future<void> updateGrams(String id, double grams) async {
    _ensureInitialized();
    final entries = _entriesNotifier.value
        .map((entry) => entry.id == id ? entry.copyWith(grams: grams) : entry)
        .toList();
    await _setEntries(entries);
  }

  Future<void> deleteEntry(String id) async {
    _ensureInitialized();
    final entries =
        _entriesNotifier.value.where((entry) => entry.id != id).toList();
    await _setEntries(entries);
  }

  Map<MealCategory, List<DiaryEntry>> entriesByCategory(DateTime day) {
    _ensureInitialized();
    final normalized = DateTime(day.year, day.month, day.day);
    final Map<MealCategory, List<DiaryEntry>> grouped = {
      for (final category in MealCategory.values) category: <DiaryEntry>[],
    };

    for (final entry in _entriesNotifier.value) {
      final entryDay = DateTime(
          entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (entryDay == normalized) {
        grouped[entry.category]?.add(entry);
      }
    }

    for (final category in MealCategory.values) {
      grouped[category]?.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return grouped;
  }

  DailyTotals? totalsForDay(DateTime day) {
    _ensureInitialized();
    final normalized = DateTime(day.year, day.month, day.day);
    DailyTotals? totals;
    for (final entry in _entriesNotifier.value) {
      final entryDay = DateTime(
          entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (entryDay == normalized) {
        totals = (totals ?? DailyTotals.zero()).add(entry);
      }
    }
    return totals;
  }

  Map<DateTime, DailyTotals> totalsByDay() {
    _ensureInitialized();
    final Map<DateTime, DailyTotals> totals = <DateTime, DailyTotals>{};
    for (final entry in _entriesNotifier.value) {
      final day = DateTime(
          entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      totals.update(
        day,
        (value) => value.add(entry),
        ifAbsent: () => DailyTotals.fromEntry(entry),
      );
    }
    return totals;
  }

  Future<void> _setEntries(List<DiaryEntry> entries) async {
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _entriesNotifier.value = List<DiaryEntry>.unmodifiable(entries);
    await _persistEntries();
  }

  Future<void> _persistEntries() async {
    if (_preferences == null) {
      return;
    }
    final payload = jsonEncode(
      _entriesNotifier.value.map((entry) => entry.toJson()).toList(),
    );
    await _preferences!.setString(_storageKey, payload);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'DiaryService.init() должен быть вызван до использования.');
    }
  }
}

class DailyTotals {
  const DailyTotals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  factory DailyTotals.zero() => const DailyTotals(
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
