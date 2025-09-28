import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class AppDatabase {
  static const _dbName = 'inventory.db';
  static const _dbVersion = 1;

  static Database? _instance;

  AppDatabase._();

  static Future<Database> get instance async {
    if (_instance != null) return _instance!;
    // For web we must use the ffi web factory and avoid getDatabasesPath()
    String path;
    if (kIsWeb) {
      // Change default factory on the web
      databaseFactory = databaseFactoryFfiWeb;
      // Use a simple filename on web (sqflite_ffi_web uses indexedDB under the hood)
      path = _dbName;
    } else {
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, _dbName);
    }

    _instance = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inventory (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            weightKg REAL NOT NULL,
            expiry TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE wasted (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            weightKg REAL NOT NULL,
            expiry TEXT NOT NULL,
            movedAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE meal_plans (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            prepTimeMinutes INTEGER NOT NULL,
            tags TEXT,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE meal_plan_ingredients (
            id TEXT PRIMARY KEY,
            ingredientId TEXT NOT NULL,
            mealPlanId TEXT NOT NULL,
            name TEXT NOT NULL,
            requiredQuantity INTEGER NOT NULL,
            requiredWeightKg REAL NOT NULL,
            FOREIGN KEY (ingredientId) REFERENCES inventory (id) ON DELETE SET NULL,
            FOREIGN KEY (mealPlanId) REFERENCES meal_plans (id) ON DELETE CASCADE
          )
        ''');

        // Add other tables as needed
      },
    );

    return _instance!;
  }

  static Future<void> close() async {
    final db = _instance;
    if (db != null) {
      await db.close();
      _instance = null;
    }
  }
}
