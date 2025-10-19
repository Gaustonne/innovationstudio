import 'package:sqflite/sqflite.dart';
import '../db.dart';
import '../models/ingredient.dart';
import '../models/wasted_item.dart';

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

    map.remove('expiry');
    map.remove('category');
    map.remove('status');
    map.remove('priceOptions');
    map.remove('selectedStore');

    map['origExpiry'] = item.expiry.toIso8601String();
    map['movedAt'] = (movedAt ?? DateTime.now()).millisecondsSinceEpoch;

    await db.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}

class WasteWeeklySummary {
  final int itemCount;
  final double totalValue;
  const WasteWeeklySummary({required this.itemCount, required this.totalValue});
}

extension WastedStoreExtras on WastedStore {
  Future<void> insertManual(WastedItem item) async {
    final db = await AppDatabase.instance;
    final map = item.toMap();
    map['movedAt'] = item.movedAt.millisecondsSinceEpoch;
    await db.insert(WastedStore.table, map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WastedItem>> listRecent({int limit = 50}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      WastedStore.table,
      orderBy: 'movedAt DESC',
      limit: limit,
    );

    return rows.map((row) {
      var m = Map<String, dynamic>.from(row);
      final raw = m['movedAt'];
      if (raw is String) {
        final iso = DateTime.tryParse(raw);
        if (iso != null) {
          m['movedAt'] = iso.millisecondsSinceEpoch;
        } else {
          final asNum = int.tryParse(raw);
          if (asNum != null) m['movedAt'] = asNum;
        }
      }
      return WastedItem.fromMap(m);
    }).toList();
  }

  Future<WasteWeeklySummary> getWeeklySummary() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final items = await listRecent(limit: 5000);

    final filtered = items.where((w) => w.movedAt.isAfter(since)).toList();
    final count = filtered.length;
    final total =
        filtered.fold<double>(0.0, (acc, w) => acc + (w.estValue ?? 0.0));

    return WasteWeeklySummary(itemCount: count, totalValue: total);
  }
}