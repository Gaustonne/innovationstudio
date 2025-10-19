import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../common/db/db.dart';

/// Lightweight row model fetched from "wasted" table.
class _WasteRow {
  final String name;
  final int quantity;     // how many units wasted
  final double weightKg;  // weight if provided
  final DateTime movedAt; // when it was recorded

  _WasteRow({
    required this.name,
    required this.quantity,
    required this.weightKg,
    required this.movedAt,
  });
}

class WasteChartsScreen extends StatefulWidget {
  const WasteChartsScreen({super.key});

  @override
  State<WasteChartsScreen> createState() => _WasteChartsScreenState();
}

class _WasteChartsScreenState extends State<WasteChartsScreen> {
  late Future<_Aggregates> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAggregates();
  }

  // === Data loading & aggregation ===========================================

  Future<List<_WasteRow>> _fetchRows() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'wasted',
      columns: ['name', 'quantity', 'weightKg', 'movedAt'],
      orderBy: 'movedAt DESC',
    );
    return rows.map((r) {
      // Some older rows might not have weightKg; default to 0.0
      final weight = (r['weightKg'] is num) ? (r['weightKg'] as num).toDouble() : 0.0;
      // quantity is stored as INTEGER
      final qty = (r['quantity'] is num) ? (r['quantity'] as num).toInt() : 1;
      return _WasteRow(
        name: (r['name'] as String?) ?? 'Unknown',
        quantity: qty,
        weightKg: weight,
        movedAt: DateTime.tryParse((r['movedAt'] as String?) ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  /// Produce a list of the last N monday week starts (oldest -> newest).
  List<DateTime> _lastNWeeks(int n, DateTime now) {
    final start = _mondayOf(now);
    return List.generate(n, (i) => _mondayOf(start.subtract(Duration(days: (n - 1 - i) * 7))));
  }

  Future<_Aggregates> _loadAggregates() async {
    final rows = await _fetchRows();
    final now = DateTime.now();
    final weeks = _lastNWeeks(8, now); // 8 weeks window
    final weekKeys = weeks.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

    // Initialize week buckets
    final itemsPerWeek = {for (final k in weekKeys) k: 0};
    final weightPerWeek = {for (final k in weekKeys) k: 0.0};

    // Top wasted items by count
    final byItemCount = <String, int>{};
    // Optionally, by weight if you want to show another chart later
    final byItemWeight = <String, double>{};

    for (final r in rows) {
      final wk = _mondayOf(r.movedAt);
      final key = DateFormat('yyyy-MM-dd').format(wk);
      if (itemsPerWeek.containsKey(key)) {
        itemsPerWeek[key] = (itemsPerWeek[key] ?? 0) + max(1, r.quantity);
        weightPerWeek[key] = (weightPerWeek[key] ?? 0.0) + (r.weightKg * max(1, r.quantity));
      }

      byItemCount[r.name] = (byItemCount[r.name] ?? 0) + max(1, r.quantity);
      byItemWeight[r.name] = (byItemWeight[r.name] ?? 0.0) + (r.weightKg * max(1, r.quantity));
    }

    // Build chart points in x-order 0..7 (oldest to newest)
    final weekLabels = weeks.map((d) => DateFormat('d MMM').format(d)).toList();

    final linePoints = List<FlSpot>.generate(
      weeks.length,
          (i) => FlSpot(i.toDouble(), (itemsPerWeek[weekKeys[i]] ?? 0).toDouble()),
    );

    // Top-5 items by count
    final top5 = byItemCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topBars = top5.take(5).toList();

    return _Aggregates(
      weekLabels: weekLabels,
      itemsPerWeekSpots: linePoints,
      topItems: topBars,
    );
  }

  // === UI ====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Insights'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() => _future = _loadAggregates()),
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: FutureBuilder<_Aggregates>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load charts:\n${snap.error}'),
              ),
            );
          }
          final data = snap.data!;
          final hasAny =
              data.itemsPerWeekSpots.any((s) => s.y > 0) || data.topItems.isNotEmpty;

          if (!hasAny) {
            return const _EmptyState();
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SectionHeader(
                title: 'Weekly waste (last 8 weeks)',
                subtitle: 'Total items thrown away each week',
                icon: Icons.show_chart,
              ),
              _WeeklyLineChart(
                labels: data.weekLabels,
                points: data.itemsPerWeekSpots,
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Top wasted items',
                subtitle: 'Most frequently discarded (Top 5)',
                icon: Icons.bar_chart,
              ),
              _TopItemsBarChart(top: data.topItems),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

// === Aggregates container =====================================================

class _Aggregates {
  final List<String> weekLabels;
  final List<FlSpot> itemsPerWeekSpots;
  final List<MapEntry<String, int>> topItems;

  _Aggregates({
    required this.weekLabels,
    required this.itemsPerWeekSpots,
    required this.topItems,
  });
}

// === Widgets: headers and charts =============================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle),
    );
  }
}

class _WeeklyLineChart extends StatelessWidget {
  final List<String> labels; // 8 labels
  final List<FlSpot> points; // 8 spots (x = 0..7)

  const _WeeklyLineChart({
    required this.labels,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = max<double>(4, points.map((e) => e.y).fold<double>(0, max));

    return AspectRatio(
      aspectRatio: 1.6,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 24, 20),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: 0,
              maxY: maxY + 1,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: max(1, (maxY / 4).ceilToDouble()),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= labels.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[i],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  spots: points,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopItemsBarChart extends StatelessWidget {
  final List<MapEntry<String, int>> top;

  const _TopItemsBarChart({required this.top});

  @override
  Widget build(BuildContext context) {
    final bars = List.generate(
      top.length,
          (i) => BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: top[i].value.toDouble(),
            width: 18,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      ),
    );

    final maxY = max<double>(4, top.map((e) => e.value.toDouble()).fold(0, max));

    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: BarChart(
            BarChartData(
              maxY: maxY + 1,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: max(1, (maxY / 4).ceilToDouble()),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= top.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          top[i].key,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: bars,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48),
            const SizedBox(height: 8),
            Text(
              'No waste recorded yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Log items you throw away to see trends here.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
