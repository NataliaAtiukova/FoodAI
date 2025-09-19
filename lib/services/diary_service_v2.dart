import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry_v2.dart';
import '../models/meal_category.dart';
import '../models/nutrition_models.dart';

class DiaryServiceV2Exception implements Exception {
  DiaryServiceV2Exception(this.message);
  final String message;

  @override
  String toString() => 'DiaryServiceV2Exception: $message';
}

class DiaryServiceV2 {
  DiaryServiceV2._();
  static final DiaryServiceV2 instance = DiaryServiceV2._();

  static const String _diaryKey = 'diary_entries_v2';
  static const String _legacyDiaryKey = 'diary_entries_v1';
  List<DiaryEntryV2> _entries = [];
  bool _isInitialized = false;
  final ValueNotifier<List<DiaryEntryV2>> _entriesNotifier =
      ValueNotifier<List<DiaryEntryV2>>(const <DiaryEntryV2>[]);

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {
        // reload недоступен на некоторых платформах (iOS/Android)
      }
      final entriesJson = prefs.getString(_diaryKey);

      if (entriesJson != null) {
        final List<dynamic> entriesList = jsonDecode(entriesJson);
        _entries = entriesList
            .map((json) => DiaryEntryV2.fromJson(json as Map<String, dynamic>))
            .toList();
        _sortEntries();
        debugPrint('DiaryServiceV2:init loaded ${_entries.length} entries');
      } else {
        final migrated = await _tryMigrateLegacyEntries(prefs);
        if (!migrated) {
          _entries = [];
        }
      }

      _isInitialized = true;
      _notifyListeners();
    } catch (e) {
      throw DiaryServiceV2Exception('Ошибка инициализации дневника: $e');
    }
  }

  Future<void> addEntry(DiaryEntryV2 entry) async {
    if (!_isInitialized) await init();

    _entries.add(entry);
    _sortEntries();
    _notifyListeners();
    await _saveEntries();
    debugPrint('DiaryServiceV2:add stored ${_entries.length} entries');
  }

  Future<void> updateEntry(DiaryEntryV2 entry) async {
    if (!_isInitialized) await init();

    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      _sortEntries();
      _notifyListeners();
      await _saveEntries();
      debugPrint('DiaryServiceV2:update entry ${entry.id}');
    }
  }

  Future<void> removeEntry(String id) async {
    if (!_isInitialized) await init();

    final before = _entries.length;
    _entries.removeWhere((entry) => entry.id == id);
    _sortEntries();
    _notifyListeners();
    await _saveEntries();
    if (before != _entries.length) {
      debugPrint('DiaryServiceV2:remove entry $id, left ${_entries.length}');
    }
  }

  List<DiaryEntryV2> getAllEntries() {
    if (!_isInitialized) {
      return const <DiaryEntryV2>[];
    }
    return List.unmodifiable(_entries);
  }

  List<DiaryEntryV2> getEntriesForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _entries
        .where((entry) =>
            !entry.timestamp.isBefore(startOfDay) &&
            entry.timestamp.isBefore(endOfDay))
        .toList();
  }

  List<DiaryEntryV2> getEntriesByCategory(MealCategory category) {
    return _entries.where((entry) => entry.category == category).toList();
  }

  List<DiaryEntryV2> getEntriesForDateByCategory(
      DateTime date, MealCategory category) {
    final entriesForDate = getEntriesForDate(date);
    return entriesForDate.where((entry) => entry.category == category).toList();
  }

  Map<MealCategory, List<DiaryEntryV2>> getEntriesGroupedByCategory(
      DateTime date) {
    final result = <MealCategory, List<DiaryEntryV2>>{};

    for (final category in MealCategory.values) {
      result[category] = getEntriesForDateByCategory(date, category);
    }

    return result;
  }

  Map<String, dynamic> getNutritionSummaryForDate(DateTime date) {
    final entries = getEntriesForDate(date);

    double totalCalories = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCarbs = 0;

    for (final entry in entries) {
      final facts = entry.factsForCurrentServing;
      totalCalories += facts.calories;
      totalProtein += facts.protein;
      totalFat += facts.fat;
      totalCarbs += facts.carbs;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'fat': totalFat,
      'carbs': totalCarbs,
      'entryCount': entries.length,
    };
  }

  Future<void> _saveEntries({SharedPreferences? existingPrefs}) async {
    try {
      final prefs = existingPrefs ?? await SharedPreferences.getInstance();
      final entriesJson = jsonEncode(_entries.map((e) => e.toJson()).toList());
      final ok = await prefs.setString(_diaryKey, entriesJson);
      if (!ok) {
        debugPrint('DiaryServiceV2: setString returned false for $_diaryKey');
      }
    } catch (e) {
      throw DiaryServiceV2Exception('Ошибка сохранения дневника: $e');
    }
  }

  Future<void> clearAllEntries() async {
    _entries.clear();
    _notifyListeners();
    await _saveEntries();
  }

  ValueListenable<List<DiaryEntryV2>> listenable() {
    return _entriesNotifier;
  }

  void _notifyListeners() {
    _entriesNotifier.value = List<DiaryEntryV2>.unmodifiable(_entries);
    debugPrint('DiaryServiceV2:notifier updated ${_entries.length} entries');
  }

  @visibleForTesting
  void resetForTesting() {
    _isInitialized = false;
    _entries = [];
    _notifyListeners();
  }

  Future<bool> _tryMigrateLegacyEntries(SharedPreferences prefs) async {
    final legacyJson = prefs.getString(_legacyDiaryKey);
    if (legacyJson == null || legacyJson.isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(legacyJson);
      if (decoded is! List) {
        return false;
      }

      final migrated = <DiaryEntryV2>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final entry = _legacyEntryFromJson(item);
        if (entry != null) {
          migrated.add(entry);
        }
      }

      if (migrated.isEmpty) {
        return false;
      }

      migrated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _entries = migrated;
      await _saveEntries(existingPrefs: prefs);
      await prefs.remove(_legacyDiaryKey);
      debugPrint('DiaryServiceV2: migrated ${migrated.length} legacy entries');
      return true;
    } catch (_) {
      return false;
    }
  }

  DiaryEntryV2? _legacyEntryFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = (json['name'] as String?)?.trim();
    if (id == null || name == null || name.isEmpty) {
      return null;
    }

    final brandRaw = (json['brand'] as String?)?.trim();
    final brand = brandRaw == null || brandRaw.isEmpty ? null : brandRaw;

    final storedGrams = _parseDouble(json['grams']);
    final hasNewFormat = storedGrams > 0;
    final grams = hasNewFormat ? storedGrams : 100.0;

    double resolvePer100(String key, String legacyKey) {
      if (json.containsKey(key)) {
        return _parseDouble(json[key]);
      }
      final legacy = _parseDouble(json[legacyKey]);
      if (grams == 0) {
        return legacy;
      }
      return legacy * 100.0 / grams;
    }

    final facts = NutritionFacts(
      calories: resolvePer100('calories_per_100g', 'calories'),
      protein: resolvePer100('protein_per_100g', 'protein'),
      fat: resolvePer100('fat_per_100g', 'fat'),
      carbs: resolvePer100('carbs_per_100g', 'carbs'),
    );

    final timestamp =
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final category =
        MealCategoryExt.fromStorage(json['category'] as String? ?? 'snack');
    final source = json['source'] as String? ?? 'Legacy';
    final note = json['note'] as String?;
    final imagePath = (json['imagePath'] ?? json['image_path']) as String?;
    final labels =
        (json['labels'] as List?)?.map((dynamic e) => e.toString()).toList();

    return DiaryEntryV2(
      id: id,
      name: name,
      brand: brand,
      grams: grams > 0 ? grams : 100.0,
      factsPer100g: facts,
      timestamp: timestamp,
      category: category,
      source: source,
      note: note,
      imagePath: imagePath,
      labels: labels,
    );
  }

  double _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  void _sortEntries() {
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}
