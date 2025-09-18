import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static const _dbName = 'inventory.db';
  static const _dbVersion = 1;

  static Database? _instance;

  AppDatabase._();

  static Future<Database> get instance async {
    if (_instance != null) return _instance!;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

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
