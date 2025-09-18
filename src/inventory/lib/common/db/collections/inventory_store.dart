import 'package:sqflite/sqflite.dart';
import '../db.dart';
import '../models/ingredient.dart';

class InventoryStore {
  static const table = 'inventory';

  Future<List<Ingredient>> getAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(table);
    return rows.map((r) => Ingredient.fromMap(r)).toList();
  }

  Future<void> insert(Ingredient item) async {
    final db = await AppDatabase.instance;
    await db.insert(
      table,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Ingredient item) async {
    final db = await AppDatabase.instance;
    await db.update(table, item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
