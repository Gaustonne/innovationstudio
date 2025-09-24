import 'package:sqflite/sqflite.dart';
import '../db.dart';
import '../models/ingredient.dart';

class WastedStore {
  static const table = 'wasted';

  Future<List<Ingredient>> getAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(table, orderBy: 'movedAt DESC');
    return rows.map((r) => Ingredient.fromMap(r)).toList();
  }

  Future<void> insert(Ingredient item, {DateTime? movedAt}) async {
    final db = await AppDatabase.instance;
    final map = item.toMap();
    map['movedAt'] = (movedAt ?? DateTime.now()).toIso8601String();
    await db.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
