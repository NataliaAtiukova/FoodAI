import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import '../models/advice_entry.dart';
import '../models/meal_plan_entry.dart';
import '../models/recipe_entry.dart';
import 'app_database.dart';

class AiHistoryService {
  AiHistoryService._();

  static final AiHistoryService instance = AiHistoryService._();

  final ValueNotifier<List<AdviceEntry>> _adviceNotifier =
      ValueNotifier<List<AdviceEntry>>(const <AdviceEntry>[]);
  final ValueNotifier<List<RecipeEntry>> _recipeNotifier =
      ValueNotifier<List<RecipeEntry>>(const <RecipeEntry>[]);
  final ValueNotifier<List<MealPlanEntry>> _mealPlanNotifier =
      ValueNotifier<List<MealPlanEntry>>(const <MealPlanEntry>[]);

  bool _initialized = false;
  final Uuid _uuid = const Uuid();

  Future<void> init() async {
    if (_initialized) return;

    final db = await AppDatabase.instance.database;
    await _reloadAdvice(db);
    await _reloadRecipes(db);
    await _reloadMealPlans(db);

    _initialized = true;
  }

  ValueListenable<List<AdviceEntry>> get adviceListenable => _adviceNotifier;
  ValueListenable<List<RecipeEntry>> get recipeListenable => _recipeNotifier;
  ValueListenable<List<MealPlanEntry>> get mealPlanListenable =>
      _mealPlanNotifier;

  Future<AdviceEntry> saveAdvice(String text) async {
    final entry = AdviceEntry(
      id: _uuid.v4(),
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    final db = await AppDatabase.instance.database;
    await db.insert('advice', entry.toMap());
    _adviceNotifier.value = <AdviceEntry>[entry, ..._adviceNotifier.value];
    return entry;
  }

  Future<List<RecipeEntry>> saveRecipes(
      List<Map<String, dynamic>> recipes) async {
    if (recipes.isEmpty) return const <RecipeEntry>[];

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    final now = DateTime.now();
    final created = <RecipeEntry>[];

    for (var i = 0; i < recipes.length; i++) {
      final recipe = recipes[i];
      final createdAt = now.subtract(Duration(milliseconds: i));
      final entry = RecipeEntry(
        id: _uuid.v4(),
        title: (recipe['title'] ?? 'Рецепт').toString(),
        text: jsonEncode(recipe),
        createdAt: createdAt,
      );
      batch.insert('recipes', entry.toMap());
      created.add(entry);
    }

    await batch.commit(noResult: true);
    _recipeNotifier.value = <RecipeEntry>[...created, ..._recipeNotifier.value];
    return created;
  }

  Future<MealPlanEntry> saveMealPlan({
    required String title,
    required Map<String, dynamic> payload,
  }) async {
    final entry = MealPlanEntry(
      id: _uuid.v4(),
      title: title,
      text: jsonEncode(payload),
      createdAt: DateTime.now(),
    );

    final db = await AppDatabase.instance.database;
    await db.insert('meal_plans', entry.toMap());
    _mealPlanNotifier.value = <MealPlanEntry>[
      entry,
      ..._mealPlanNotifier.value,
    ];
    return entry;
  }

  Future<void> deleteAdvice(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('advice', where: 'id = ?', whereArgs: [id]);
    _adviceNotifier.value =
        _adviceNotifier.value.where((entry) => entry.id != id).toList();
  }

  Future<void> deleteRecipe(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
    _recipeNotifier.value =
        _recipeNotifier.value.where((entry) => entry.id != id).toList();
  }

  Future<void> deleteMealPlan(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);
    _mealPlanNotifier.value =
        _mealPlanNotifier.value.where((entry) => entry.id != id).toList();
  }

  Future<void> _reloadAdvice(Database db) async {
    final rows = await db.query(
      'advice',
      orderBy: 'created_at DESC',
      limit: 50,
    );
    _adviceNotifier.value =
        rows.map((map) => AdviceEntry.fromMap(map)).toList(growable: false);
  }

  Future<void> _reloadRecipes(Database db) async {
    final rows = await db.query(
      'recipes',
      orderBy: 'created_at DESC',
      limit: 100,
    );
    _recipeNotifier.value =
        rows.map((map) => RecipeEntry.fromMap(map)).toList(growable: false);
  }

  Future<void> _reloadMealPlans(Database db) async {
    final rows = await db.query(
      'meal_plans',
      orderBy: 'created_at DESC',
      limit: 30,
    );
    _mealPlanNotifier.value =
        rows.map((map) => MealPlanEntry.fromMap(map)).toList(growable: false);
  }
}
