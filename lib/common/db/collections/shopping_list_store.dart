import 'package:sqflite/sqflite.dart';
import '../db.dart';
import '../models/shopping_list_item.dart';

class ShoppingListStore {
  Future<void> insert(ShoppingListItem item) async {
    final db = await AppDatabase.instance;

    final List<Map<String, dynamic>> existingItems = await db.query(
      'shopping_list',
      where: 'LOWER(name) = ? AND unit = ?',
      whereArgs: [item.name.toLowerCase(), item.unit],
    );

    if (existingItems.isNotEmpty) {
      final existingItem = ShoppingListItem.fromMap(existingItems.first);
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + item.quantity,
      );
      await update(updatedItem);
    } else {
      await db.insert(
        'shopping_list',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> update(ShoppingListItem item) async {
    final db = await AppDatabase.instance;
    await db.update(
      'shopping_list',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'shopping_list',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ShoppingListItem>> getAll() async {
    final db = await AppDatabase.instance;
    final maps = await db.query('shopping_list');
    return maps.map((map) => ShoppingListItem.fromMap(map)).toList();
  }
}
