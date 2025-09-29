import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/diary_entry_v2.dart';
import '../models/meal_category.dart';
import '../models/nutrition_models.dart';
import 'app_database.dart';

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
      final db = await AppDatabase.instance.database;
      await _loadFromDatabase(db);
      if (_entries.isEmpty) {
        final migrated = await _tryMigrateFromPreferences(db);
        if (migrated) {
          await _loadFromDatabase(db);
        }
      }
      _isInitialized = true;
      _notifyListeners();
    } catch (error) {
      throw DiaryServiceV2Exception('Ошибка инициализации дневника: $error');
    }
  }

  Future<void> addEntry(DiaryEntryV2 entry) async {
    if (!_isInitialized) await init();

    final db = await AppDatabase.instance.database;
    await db.insert(
      'diary_entries',
      _toDbMap(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _entries.add(entry);
    _sortEntries();
    _notifyListeners();
    debugPrint('DiaryServiceV2:add stored ${_entries.length} entries');
  }

  Future<void> updateEntry(DiaryEntryV2 entry) async {
    if (!_isInitialized) await init();

    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      return;
    }

    final db = await AppDatabase.instance.database;
    await db.update(
      'diary_entries',
      _toDbMap(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _entries[index] = entry;
    _sortEntries();
    _notifyListeners();
    debugPrint('DiaryServiceV2:update entry ${entry.id}');
  }

  Future<void> removeEntry(String id) async {
    if (!_isInitialized) await init();

    final before = _entries.length;
    final db = await AppDatabase.instance.database;
    await db.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
    _entries.removeWhere((entry) => entry.id == id);
    _sortEntries();
    _notifyListeners();
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

  Future<void> clearAllEntries() async {
    final db = await AppDatabase.instance.database;
    await db.delete('diary_entries');
    _entries.clear();
    _notifyListeners();
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

  Future<void> _loadFromDatabase(Database db) async {
    final rows = await db.query(
      'diary_entries',
      orderBy: 'timestamp DESC',
    );
    _entries = rows.map(_fromDbMap).toList();
    _sortEntries();
  }

  Future<bool> _tryMigrateFromPreferences(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {
        // reload недоступен на некоторых платформах (iOS/Android)
      }

      final migratedEntries = <DiaryEntryV2>[];
      final modernJson = prefs.getString(_diaryKey);
      if (modernJson != null && modernJson.isNotEmpty) {
        final decoded = jsonDecode(modernJson);
        if (decoded is List) {
          migratedEntries.addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(DiaryEntryV2.fromJson),
          );
        }
      }

      final legacyJson = prefs.getString(_legacyDiaryKey);
      if (legacyJson != null && legacyJson.isNotEmpty) {
        final decoded = jsonDecode(legacyJson);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) continue;
            final entry = _legacyEntryFromJson(item);
            if (entry != null) {
              migratedEntries.add(entry);
            }
          }
        }
      }

      if (migratedEntries.isEmpty) {
        return false;
      }

      final batch = db.batch();
      for (final entry in migratedEntries) {
        batch.insert(
          'diary_entries',
          _toDbMap(entry),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      await prefs.remove(_diaryKey);
      await prefs.remove(_legacyDiaryKey);

      debugPrint(
        'DiaryServiceV2: migrated ${migratedEntries.length} entries to SQLite',
      );
      return true;
    } catch (error) {
      debugPrint('DiaryServiceV2: failed to migrate legacy entries: $error');
      return false;
    }
  }

  Map<String, Object?> _toDbMap(DiaryEntryV2 entry) => <String, Object?>{
        'id': entry.id,
        'name': entry.name,
        'brand': entry.brand,
        'grams': entry.grams,
        'calories_per_100': entry.factsPer100g.calories,
        'protein_per_100': entry.factsPer100g.protein,
        'fat_per_100': entry.factsPer100g.fat,
        'carbs_per_100': entry.factsPer100g.carbs,
        'timestamp': entry.timestamp.millisecondsSinceEpoch,
        'category': entry.category.storageValue,
        'source': entry.source,
        'note': entry.note,
        'image_path': entry.imagePath,
        'labels': entry.labels == null ? null : jsonEncode(entry.labels),
      };

  DiaryEntryV2 _fromDbMap(Map<String, Object?> map) {
    final labelsRaw = map['labels'];
    List<String>? labels;
    if (labelsRaw is String && labelsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(labelsRaw) as List<dynamic>;
        labels = decoded.map((e) => e.toString()).toList();
      } catch (_) {
        labels = null;
      }
    }

    return DiaryEntryV2(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      grams: (map['grams'] as num).toDouble(),
      factsPer100g: NutritionFacts(
        calories: (map['calories_per_100'] as num).toDouble(),
        protein: (map['protein_per_100'] as num).toDouble(),
        fat: (map['fat_per_100'] as num).toDouble(),
        carbs: (map['carbs_per_100'] as num).toDouble(),
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as num).toInt()),
      category: MealCategoryExt.fromStorage(map['category'] as String?),
      source: map['source'] as String,
      note: map['note'] as String?,
      imagePath: map['image_path'] as String?,
      labels: labels,
    );
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
