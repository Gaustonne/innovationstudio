import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models/ingredient.dart';

/// Data point for charts (weekly totals).
@immutable
class WastePoint {
  final DateTime weekStart; // Monday (00:00) of the week
  final num totalCount;     // sum of quantity columns
  final num totalWeightKg;  // sum of weightKg columns

  const WastePoint({
    required this.weekStart,
    required this.totalCount,
    required this.totalWeightKg,
  });
}

/// “Top wasted items” for leaderboards / bar charts.
@immutable
class TopWasteItem {
  final String name;        // ingredient name
  final num totalCount;     // sum of quantity columns
  final num totalWeightKg;  // sum of weightKg columns

  const TopWasteItem({
    required this.name,
    required this.totalCount,
    required this.totalWeightKg,
  });
}

class WastedStore {
  static const table = 'wasted';

  /// Existing: list all wasted records (most recent first).
  Future<List<Ingredient>> getAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(table, orderBy: 'movedAt DESC');
    return rows.map((r) => Ingredient.fromMap(r)).toList();
  }

  /// Existing: insert a record into the wasted table.
  Future<void> insert(Ingredient item, {DateTime? movedAt}) async {
    final db = await AppDatabase.instance;
    final map = item.toMap();
    map['movedAt'] = (movedAt ?? DateTime.now()).toIso8601String();
    await db.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Existing: delete a wasted record by id.
  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // NEW: Aggregation helpers for charts
  // ---------------------------------------------------------------------------

  /// Returns totals grouped by ISO week (we use Monday as week start).
  /// If [weeks] is given, it returns the most recent N full weeks (including the
  /// current week). Otherwise, provide an explicit [from]…[to] range.
  Future<List<WastePoint>> weeklyTotals({
    int? weeks,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await AppDatabase.instance;

    // Decide the time window.
    DateTime start;
    DateTime end;

    if (weeks != null) {
      final now = DateTime.now();
      final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));
      end = DateTime(mondayThisWeek.year, mondayThisWeek.month, mondayThisWeek.day, 23, 59, 59, 999);
      start = mondayThisWeek.subtract(Duration(days: (weeks - 1) * 7));
    } else {
      if (from == null || to == null) {
        throw ArgumentError('Provide either weeks OR from/to.');
      }
      start = from;
      end = to;
    }

    // SQLite: normalise to Monday using strftime('%w', movedAt).
    // We set the week-start (Mon) by subtracting (weekday-1) days.
    // In SQLite we can derive a "week start date" string as YYYY-MM-DD.
    final sql = '''
      SELECT
        date(
          datetime(movedAt),
          '-' || ((strftime('%w', movedAt) + 6) % 7) || ' days'
        ) AS week_start,
        SUM(quantity) AS total_count,
        SUM(weightKg) AS total_weight
      FROM $table
      WHERE datetime(movedAt) BETWEEN ? AND ?
      GROUP BY week_start
      ORDER BY week_start ASC
    ''';

    final rows = await db.rawQuery(sql, [
      start.toIso8601String(),
      end.toIso8601String(),
    ]);

    return rows.map((r) {
      final weekDate = DateTime.parse('${r['week_start']}T00:00:00.000');
      return WastePoint(
        weekStart: weekDate,
        totalCount: (r['total_count'] as num?) ?? 0,
        totalWeightKg: (r['total_weight'] as num?) ?? 0,
      );
    }).toList();
  }

  /// Convenience wrapper: last N weeks (default 8).
  Future<List<WastePoint>> lastNWeeksTotals({int weeks = 8}) {
    return weeklyTotals(weeks: weeks);
  }

  /// Top N wasted items by total quantity and weight in a given period.
  Future<List<TopWasteItem>> topWastedItems({
    required DateTime from,
    required DateTime to,
    int limit = 5,
  }) async {
    final db = await AppDatabase.instance;
    final sql = '''
      SELECT
        name,
        SUM(quantity) AS total_count,
        SUM(weightKg) AS total_weight
      FROM $table
      WHERE datetime(movedAt) BETWEEN ? AND ?
      GROUP BY name
      ORDER BY total_weight DESC, total_count DESC
      LIMIT $limit
    ''';

    final rows = await db.rawQuery(sql, [
      from.toIso8601String(),
      to.toIso8601String(),
    ]);

    return rows.map((r) {
      return TopWasteItem(
        name: (r['name'] as String?) ?? 'Unknown',
        totalCount: (r['total_count'] as num?) ?? 0,
        totalWeightKg: (r['total_weight'] as num?) ?? 0,
      );
    }).toList();
  }

  /// Daily totals (useful if you prefer a finer-grained line chart).
  Future<List<WastePoint>> dailyTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await AppDatabase.instance;
    final sql = '''
      SELECT
        date(datetime(movedAt)) AS day,
        SUM(quantity) AS total_count,
        SUM(weightKg) AS total_weight
      FROM $table
      WHERE datetime(movedAt) BETWEEN ? AND ?
      GROUP BY day
      ORDER BY day ASC
    ''';

    final rows = await db.rawQuery(sql, [
      from.toIso8601String(),
      to.toIso8601String(),
    ]);

    return rows.map((r) {
      final day = DateTime.parse('${r['day']}T00:00:00.000');
      return WastePoint(
        weekStart: day, // reuse field; caller knows this is “day”
        totalCount: (r['total_count'] as num?) ?? 0,
        totalWeightKg: (r['total_weight'] as num?) ?? 0,
      );
    }).toList();
  }
}
