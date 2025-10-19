import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';

class WeeklyPlanEntry {
  final int dayIndex;        // 0..6 (Mon..Sun)
  final String mealType;     // 'breakfast' | 'lunch' | 'dinner'
  final String recipeId;     // recipes.id
  final String recipeName;   // convenience for UI
  final int servings;

  WeeklyPlanEntry({
    required this.dayIndex,
    required this.mealType,
    required this.recipeId,
    required this.recipeName,
    required this.servings,
  });
}

class MealPlanStore {
  final _uuid = const Uuid();

  /// Monday (00:00) ISO date string (yyyy-MM-dd)
  String _isoMonday(DateTime any) {
    final mon = any.subtract(Duration(days: any.weekday - 1));
    final d = DateTime(mon.year, mon.month, mon.day);
    return d.toIso8601String().substring(0, 10);
  }

  Future<String> _getOrCreatePlanId(DateTime weekStart) async {
    final db = await AppDatabase.instance;
    final iso = _isoMonday(weekStart);

    final rows = await db.query(
      'weekly_plan',
      where: 'week_start = ?',
      whereArgs: [iso],
      limit: 1,
    );

    if (rows.isNotEmpty) return rows.first['id'] as String;

    final id = _uuid.v4();
    await db.insert('weekly_plan', {
      'id': id,
      'week_start': iso,
    });
    return id;
  }

  /// Load entries for the week (joins recipe name for convenience).
  Future<List<WeeklyPlanEntry>> loadWeek(DateTime weekStart) async {
    final db = await AppDatabase.instance;
    final iso = _isoMonday(weekStart);

    final rows = await db.rawQuery('''
      SELECT wpe.dayIndex AS di,
             wpe.mealType AS mt,
             wpe.recipeId AS rid,
             COALESCE(r.name, '') AS rname,
             wpe.servings AS sv
      FROM weekly_plan_entry wpe
      JOIN weekly_plan wp ON wp.id = wpe.planId
      LEFT JOIN recipes r   ON r.id = wpe.recipeId
      WHERE wp.week_start = ?
      ORDER BY wpe.dayIndex, wpe.mealType
    ''', [iso]);

    return rows.map((r) => WeeklyPlanEntry(
      dayIndex: r['di'] as int,
      mealType: r['mt'] as String,
      recipeId: r['rid'] as String,
      recipeName: (r['rname'] as String?) ?? '',
      servings: (r['sv'] as int?) ?? 1,
    )).toList();
  }

  /// Set/replace a single slot (upsert via unique index).
  Future<void> setSlot({
    required DateTime weekStart,
    required int dayIndex,
    required String mealType,
    required String recipeId,
    int servings = 2,
  }) async {
    final db = await AppDatabase.instance;
    final planId = await _getOrCreatePlanId(weekStart);

    await db.insert(
      'weekly_plan_entry',
      {
        'id': _uuid.v4(),
        'planId': planId,
        'dayIndex': dayIndex,
        'mealType': mealType,
        'recipeId': recipeId,
        'servings': servings,
      },
      // because (planId, dayIndex, mealType) is unique
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSlot({
    required DateTime weekStart,
    required int dayIndex,
    required String mealType,
  }) async {
    final db = await AppDatabase.instance;
    final planId = await _getOrCreatePlanId(weekStart);

    await db.delete(
      'weekly_plan_entry',
      where: 'planId = ? AND dayIndex = ? AND mealType = ?',
      whereArgs: [planId, dayIndex, mealType],
    );
  }

  /// Bulk save (wipe week then insert).
  Future<void> saveWholeWeek(DateTime weekStart, List<WeeklyPlanEntry> slots) async {
    final db = await AppDatabase.instance;
    final planId = await _getOrCreatePlanId(weekStart);

    await db.transaction((txn) async {
      await txn.delete('weekly_plan_entry', where: 'planId = ?', whereArgs: [planId]);
      for (final s in slots) {
        await txn.insert('weekly_plan_entry', {
          'id': _uuid.v4(),
          'planId': planId,
          'dayIndex': s.dayIndex,
          'mealType': s.mealType,
          'recipeId': s.recipeId,
          'servings': s.servings,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Fetch a minimal recipe list for selection.
  Future<List<Map<String, Object?>>> listRecipes({String query = ''}) async {
    final db = await AppDatabase.instance;
    if (query.trim().isEmpty) {
      return db.query('recipes', columns: ['id', 'name', 'cookTimeMinutes', 'tags'], orderBy: 'name');
    }
    final q = '%${query.toLowerCase()}%';
    return db.rawQuery('''
      SELECT id, name, cookTimeMinutes, tags
      FROM recipes
      WHERE LOWER(name) LIKE ? OR LOWER(IFNULL(tags,'')) LIKE ?
      ORDER BY name
    ''', [q, q]);
  }
}
