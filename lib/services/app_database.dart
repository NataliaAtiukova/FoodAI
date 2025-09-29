import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _dbName = 'foodai_app.db';
const _dbVersion = 1;

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;
  final _openCompleter = Completer<Database>();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_openCompleter.isCompleted) {
      _database = await _openCompleter.future;
      return _database!;
    }

    unawaited(_initDatabase());
    _database = await _openCompleter.future;
    return _database!;
  }

  Future<void> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, _dbName);
      final db = await openDatabase(
        fullPath,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      _openCompleter.complete(db);
    } catch (error, stack) {
      if (!_openCompleter.isCompleted) {
        _openCompleter.completeError(error, stack);
      }
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE diary_entries (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT,
        grams REAL NOT NULL,
        calories_per_100 REAL NOT NULL,
        protein_per_100 REAL NOT NULL,
        fat_per_100 REAL NOT NULL,
        carbs_per_100 REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        category TEXT NOT NULL,
        source TEXT NOT NULL,
        note TEXT,
        image_path TEXT,
        labels TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_diary_timestamp ON diary_entries(timestamp DESC)',
    );

    await db.execute(
      'CREATE INDEX idx_diary_category ON diary_entries(category)',
    );

    await db.execute('''
      CREATE TABLE advice (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_recipes_created_at ON recipes(created_at DESC)',
    );

    await db.execute('''
      CREATE TABLE meal_plans (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_meal_plans_created_at ON meal_plans(created_at DESC)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // No migrations yet. Reserved for future schema changes.
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }
}
