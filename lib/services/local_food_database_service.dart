import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/local_food_item.dart';
import '../models/nutrition_models.dart';

class LocalFoodDatabaseException implements Exception {
  LocalFoodDatabaseException(this.message);
  final String message;

  @override
  String toString() => 'LocalFoodDatabaseException: $message';
}

class LocalFoodDatabaseService {
  LocalFoodDatabaseService._();
  static final LocalFoodDatabaseService instance = LocalFoodDatabaseService._();

  Database? _database;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final databasePath = join(await getDatabasesPath(), 'food_database.db');

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE food_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            brand TEXT,
            calories_per_100g REAL NOT NULL,
            protein_per_100g REAL NOT NULL,
            fat_per_100g REAL NOT NULL,
            carbs_per_100g REAL NOT NULL,
            photo_url TEXT,
            barcode TEXT,
            source TEXT,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_food_items_name ON food_items(name);
        ''');

        await db.execute('''
          CREATE INDEX idx_food_items_barcode ON food_items(barcode);
        ''');
      },
    );

    _isInitialized = true;
  }

  Future<List<LocalFoodItem>> searchFoods(String query) async {
    if (!_isInitialized) await initialize();

    try {
      // Сначала ищем в локальной базе
      final localResults = await _searchLocal(query);
      if (localResults.isNotEmpty) {
        return localResults;
      }

      // Если не найдено локально, ищем в Open Food Facts RU
      final onlineResults = await _searchOpenFoodFacts(query);

      // Сохраняем найденные результаты в локальную базу
      for (final item in onlineResults) {
        await _saveFoodItem(item);
      }

      return onlineResults;
    } catch (e) {
      throw LocalFoodDatabaseException('Ошибка поиска еды: $e');
    }
  }

  Future<LocalFoodItem?> getFoodByBarcode(String barcode) async {
    if (!_isInitialized) await initialize();

    try {
      // Сначала ищем в локальной базе
      final results = await _database!.query(
        'food_items',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );

      if (results.isNotEmpty) {
        return _mapToLocalFoodItem(results.first);
      }

      // Если не найдено, ищем в Open Food Facts RU
      final onlineResult = await _getFoodByBarcodeOnline(barcode);
      if (onlineResult != null) {
        await _saveFoodItem(onlineResult);
      }

      return onlineResult;
    } catch (e) {
      throw LocalFoodDatabaseException('Ошибка поиска по штрихкоду: $e');
    }
  }

  Future<List<LocalFoodItem>> _searchLocal(String query) async {
    final results = await _database!.query(
      'food_items',
      where: 'name LIKE ? OR brand LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );

    return results.map(_mapToLocalFoodItem).toList();
  }

  Future<List<LocalFoodItem>> _searchOpenFoodFacts(String query) async {
    try {
      final uri =
          Uri.parse('https://ru.openfoodfacts.org/cgi/search.pl').replace(
        queryParameters: {
          'search_terms': query,
          'search_simple': '1',
          'action': 'process',
          'json': '1',
          'page_size': '20',
        },
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return [];
      }

      final Map<String, dynamic> payload = jsonDecode(response.body);
      final products = payload['products'] as List?;
      if (products == null) return [];

      final List<LocalFoodItem> items = [];
      for (final product in products) {
        if (product is! Map<String, dynamic>) continue;

        final item = _parseOpenFoodFactsProduct(product);
        if (item != null) {
          items.add(item);
        }
      }

      return items;
    } catch (e) {
      // Ошибка поиска в Open Food Facts - возвращаем пустой список
      return [];
    }
  }

  Future<LocalFoodItem?> _getFoodByBarcodeOnline(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://ru.openfoodfacts.org/api/v0/product/$barcode.json'),
      );

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> payload = jsonDecode(response.body);
      final product = payload['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      return _parseOpenFoodFactsProduct(product);
    } catch (e) {
      // Ошибка поиска по штрихкоду в Open Food Facts
      return null;
    }
  }

  LocalFoodItem? _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    final name = (product['product_name_ru'] as String?)?.trim() ??
        (product['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final brand = (product['brands'] as String?)?.split(',').first.trim();
    final nutriments = product['nutriments'] as Map<String, dynamic>?;

    if (nutriments == null) return null;

    double? readNutrient(String key) {
      final value = nutriments[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final calories = readNutrient('energy-kcal_100g');
    final protein = readNutrient('proteins_100g');
    final fat = readNutrient('fat_100g');
    final carbs = readNutrient('carbohydrates_100g');

    if (calories == null || protein == null || fat == null || carbs == null) {
      return null;
    }

    final facts = NutritionFacts(
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
    );

    return LocalFoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      brand: brand,
      factsPer100g: facts,
      photoUrl: product['image_thumb_url'] as String?,
      barcode: product['code'] as String?,
      source: 'openfoodfacts',
    );
  }

  Future<void> _saveFoodItem(LocalFoodItem item) async {
    await _database!.insert(
      'food_items',
      {
        'id': item.id,
        'name': item.name,
        'brand': item.brand,
        'calories_per_100g': item.factsPer100g.calories,
        'protein_per_100g': item.factsPer100g.protein,
        'fat_per_100g': item.factsPer100g.fat,
        'carbs_per_100g': item.factsPer100g.carbs,
        'photo_url': item.photoUrl,
        'barcode': item.barcode,
        'source': item.source,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  LocalFoodItem _mapToLocalFoodItem(Map<String, dynamic> map) {
    final facts = NutritionFacts(
      calories: map['calories_per_100g'] as double,
      protein: map['protein_per_100g'] as double,
      fat: map['fat_per_100g'] as double,
      carbs: map['carbs_per_100g'] as double,
    );

    return LocalFoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      factsPer100g: facts,
      photoUrl: map['photo_url'] as String?,
      barcode: map['barcode'] as String?,
      source: map['source'] as String?,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
  }
}
