import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class AppDatabase {
  static const _dbName = 'inventory.db';
  static const _dbVersion = 5; // bump to force migration

  static Database? _instance;

  AppDatabase._();

  static Future<Database> get instance async {
    if (_instance != null) return _instance!;
    String path;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      path = _dbName; // IndexedDB key
    } else {
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, _dbName);
    }

    _instance = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: add shopping_list + wasted extras
        if (oldVersion < 2) {
          await _ensureShoppingList(db);
          await _ensureWastedExtras(db);
        }
        // v2 -> v3: add origExpiry to wasted
        if (oldVersion < 3) {
          await _ensureOrigExpiry(db);
        }
        // v3 -> v4: safety pass to ensure everything exists
        if (oldVersion < 4) {
          await _ensureShoppingList(db);
          await _ensureWastedTable(db);
          await _ensureWastedExtras(db);
          await _ensureOrigExpiry(db);
        }
        // v4 -> v5: add cost tracking to inventory
        if (oldVersion < 5) {
          await _ensureCostTracking(db);
        }
      },
    );

    return _instance!;
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        weightKg REAL NOT NULL,
        expiry TEXT NOT NULL,
        costAud REAL
      )
    ''');

    await _ensureWastedTable(db);
    await _ensureWastedExtras(db);
    await _ensureOrigExpiry(db);
    await _ensureCostTracking(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_plans (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        prepTimeMinutes INTEGER NOT NULL,
        tags TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_plan_ingredients (
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cookTimeMinutes INTEGER NOT NULL,
        tags TEXT,
        ruleType TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_ingredients (
        id TEXT PRIMARY KEY,
        recipeId TEXT NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (recipeId) REFERENCES recipes (id) ON DELETE CASCADE
      )
    ''');

    await _ensureShoppingList(db);
  }

  // --- helpers to (idempotently) ensure schema pieces exist ---

  static Future<void> _ensureWastedTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wasted (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity REAL,
        unit TEXT,
        weightKg REAL,
        movedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wasted_movedAt ON wasted(movedAt)');
  }

  static Future<void> _ensureWastedExtras(Database db) async {
    // Reason + estValue (ignore if already exists)
    try { await db.execute('ALTER TABLE wasted ADD COLUMN reason TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE wasted ADD COLUMN estValue REAL'); } catch (_) {}
  }

  static Future<void> _ensureOrigExpiry(Database db) async {
    try { await db.execute('ALTER TABLE wasted ADD COLUMN origExpiry TEXT'); } catch (_) {}
  }

  static Future<void> _ensureCostTracking(Database db) async {
    try { await db.execute('ALTER TABLE inventory ADD COLUMN costAud REAL'); } catch (_) {}
    try { await db.execute('ALTER TABLE wasted ADD COLUMN costAud REAL'); } catch (_) {}
  }

  static Future<void> _ensureShoppingList(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_list (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        status TEXT NOT NULL,
        category TEXT,
        fromRecipe TEXT,
        priceOptions TEXT,
        selectedStore TEXT
      )
    ''');
  }

  static Future<void> close() async {
    final db = _instance;
    if (db != null) {
      await db.close();
      _instance = null;
    }
  }
}