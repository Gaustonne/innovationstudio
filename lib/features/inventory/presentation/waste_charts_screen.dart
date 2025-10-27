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

enum WasteAnalysisPeriod { week, month, quarter, year }

class WasteChartsScreen extends StatefulWidget {
  const WasteChartsScreen({super.key});

  @override
  State<WasteChartsScreen> createState() => _WasteChartsScreenState();
}

class _WasteChartsScreenState extends State<WasteChartsScreen> 
    with SingleTickerProviderStateMixin {
  late Future<_WasteAnalytics> _future;
  WasteAnalysisPeriod _selectedPeriod = WasteAnalysisPeriod.month;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _future = _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      // quantity is stored as INTEGER or REAL depending on how it was inserted
      final qty = (r['quantity'] is num) ? (r['quantity'] as num).toInt() : 1;
      
      // movedAt might be stored as string (ISO) or integer (milliseconds)
      DateTime parsedDate;
      final movedAtRaw = r['movedAt'];
      if (movedAtRaw is String) {
        parsedDate = DateTime.tryParse(movedAtRaw) ?? DateTime.now();
      } else if (movedAtRaw is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(movedAtRaw);
      } else {
        parsedDate = DateTime.now();
      }
      
      return _WasteRow(
        name: (r['name'] as String?) ?? 'Unknown',
        quantity: qty,
        weightKg: weight,
        movedAt: parsedDate,
      );
    }).toList();
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
  DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  /// Produce a list of the last N periods based on selected period type
  List<DateTime> _lastNPeriods(int n, DateTime now, WasteAnalysisPeriod period) {
    switch (period) {
      case WasteAnalysisPeriod.week:
        final start = _mondayOf(now);
        return List.generate(n, (i) => _mondayOf(start.subtract(Duration(days: (n - 1 - i) * 7))));
      case WasteAnalysisPeriod.month:
        final start = _firstDayOfMonth(now);
        return List.generate(n, (i) {
          final targetMonth = start.month - (n - 1 - i);
          final targetYear = start.year + (targetMonth - 1) ~/ 12;
          final adjustedMonth = ((targetMonth - 1) % 12) + 1;
          return DateTime(targetYear, adjustedMonth, 1);
        });
      case WasteAnalysisPeriod.quarter:
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final startQuarter = currentQuarter;
        return List.generate(n, (i) {
          final quarter = startQuarter - (n - 1 - i);
          final year = now.year + (quarter - 1) ~/ 4;
          final adjustedQuarter = ((quarter - 1) % 4) + 1;
          return DateTime(year, (adjustedQuarter - 1) * 3 + 1, 1);
        });
      case WasteAnalysisPeriod.year:
        return List.generate(n, (i) => DateTime(now.year - (n - 1 - i), 1, 1));
    }
  }

  Future<_WasteAnalytics> _loadAnalytics() async {
    final rows = await _fetchRows();
    final now = DateTime.now();
    
    // Calculate different period analyses
    final periods = _lastNPeriods(12, now, _selectedPeriod);
    final periodKeys = periods.map((d) {
      switch (_selectedPeriod) {
        case WasteAnalysisPeriod.week:
          return DateFormat('yyyy-MM-dd').format(d);
        case WasteAnalysisPeriod.month:
          return DateFormat('yyyy-MM').format(d);
        case WasteAnalysisPeriod.quarter:
          return '${d.year}-Q${((d.month - 1) ~/ 3) + 1}';
        case WasteAnalysisPeriod.year:
          return d.year.toString();
      }
    }).toList();

    // Initialize buckets
    final itemsPerPeriod = {for (final k in periodKeys) k: 0};
    final weightPerPeriod = {for (final k in periodKeys) k: 0.0};
    final costPerPeriod = {for (final k in periodKeys) k: 0.0};

    // Category analysis
    final categoryCount = <String, int>{};
    final categoryWeight = <String, double>{};
    
    // Time of day analysis
    final timeOfDayCount = <int, int>{}; // hour -> count
    
    // Day of week analysis
    final dayOfWeekCount = <int, int>{}; // 1-7 (Monday-Sunday)
    
    // Top wasted items by count and value
    final byItemCount = <String, int>{};
    final byItemWeight = <String, double>{};
    final estimatedValue = <String, double>{}; // Estimated cost

    // Total metrics
    var totalItems = 0;
    var totalWeight = 0.0;
    var totalEstimatedCost = 0.0;

    for (final r in rows) {
      // Determine period key
      String periodKey;
      switch (_selectedPeriod) {
        case WasteAnalysisPeriod.week:
          periodKey = DateFormat('yyyy-MM-dd').format(_mondayOf(r.movedAt));
          break;
        case WasteAnalysisPeriod.month:
          periodKey = DateFormat('yyyy-MM').format(_firstDayOfMonth(r.movedAt));
          break;
        case WasteAnalysisPeriod.quarter:
          final quarter = ((r.movedAt.month - 1) ~/ 3) + 1;
          periodKey = '${r.movedAt.year}-Q$quarter';
          break;
        case WasteAnalysisPeriod.year:
          periodKey = r.movedAt.year.toString();
          break;
      }
      
      final wasteQty = max(1, r.quantity);
      final wasteWeight = r.weightKg * wasteQty;
      final estimatedItemCost = _estimateItemCost(r.name, wasteWeight);
      
      // Period aggregation
      if (itemsPerPeriod.containsKey(periodKey)) {
        itemsPerPeriod[periodKey] = (itemsPerPeriod[periodKey] ?? 0) + wasteQty;
        weightPerPeriod[periodKey] = (weightPerPeriod[periodKey] ?? 0.0) + wasteWeight;
        costPerPeriod[periodKey] = (costPerPeriod[periodKey] ?? 0.0) + estimatedItemCost;
      }

      // Category analysis (simplified categorization)
      final category = _categorizeItem(r.name);
      categoryCount[category] = (categoryCount[category] ?? 0) + wasteQty;
      categoryWeight[category] = (categoryWeight[category] ?? 0.0) + wasteWeight;

      // Time patterns
      timeOfDayCount[r.movedAt.hour] = (timeOfDayCount[r.movedAt.hour] ?? 0) + wasteQty;
      dayOfWeekCount[r.movedAt.weekday] = (dayOfWeekCount[r.movedAt.weekday] ?? 0) + wasteQty;

      // Item aggregation
      byItemCount[r.name] = (byItemCount[r.name] ?? 0) + wasteQty;
      byItemWeight[r.name] = (byItemWeight[r.name] ?? 0.0) + wasteWeight;
      estimatedValue[r.name] = (estimatedValue[r.name] ?? 0.0) + estimatedItemCost;

      // Totals
      totalItems += wasteQty;
      totalWeight += wasteWeight;
      totalEstimatedCost += estimatedItemCost;
    }

    // Build chart data
    final periodLabels = periods.map((d) {
      switch (_selectedPeriod) {
        case WasteAnalysisPeriod.week:
          return DateFormat('d MMM').format(d);
        case WasteAnalysisPeriod.month:
          return DateFormat('MMM yy').format(d);
        case WasteAnalysisPeriod.quarter:
          return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year.toString().substring(2)}';
        case WasteAnalysisPeriod.year:
          return d.year.toString();
      }
    }).toList();

    final linePoints = List<FlSpot>.generate(
      periods.length,
      (i) => FlSpot(i.toDouble(), (itemsPerPeriod[periodKeys[i]] ?? 0).toDouble()),
    );

    final weightPoints = List<FlSpot>.generate(
      periods.length,
      (i) => FlSpot(i.toDouble(), (weightPerPeriod[periodKeys[i]] ?? 0.0)),
    );

    final costPoints = List<FlSpot>.generate(
      periods.length,
      (i) => FlSpot(i.toDouble(), (costPerPeriod[periodKeys[i]] ?? 0.0)),
    );

    // Top items
    final topItemsByCount = byItemCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItemsByValue = estimatedValue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Category data for pie chart
    final categoryChartData = categoryCount.entries.map((e) => 
      PieChartSectionData(
        value: e.value.toDouble(),
        title: '${e.key}\n${e.value}',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      )
    ).toList();

    return _WasteAnalytics(
      periodLabels: periodLabels,
      itemsPerPeriodSpots: linePoints,
      weightPerPeriodSpots: weightPoints,
      costPerPeriodSpots: costPoints,
      topItemsByCount: topItemsByCount.take(10).toList(),
      topItemsByValue: topItemsByValue.take(10).toList(),
      categoryData: categoryChartData,
      timeOfDayData: timeOfDayCount,
      dayOfWeekData: dayOfWeekCount,
      totalItems: totalItems,
      totalWeight: totalWeight,
      totalEstimatedCost: totalEstimatedCost,
      averageItemsPerPeriod: totalItems / periods.length,
      wasteReductionTrend: _calculateTrend(linePoints),
    );
  }

  String _categorizeItem(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('fruit') || lowerName.contains('apple') || 
        lowerName.contains('banana') || lowerName.contains('orange')) {
      return 'Fruits';
    } else if (lowerName.contains('vegetable') || lowerName.contains('lettuce') || 
               lowerName.contains('carrot') || lowerName.contains('potato')) {
      return 'Vegetables';
    } else if (lowerName.contains('bread') || lowerName.contains('rice') || 
               lowerName.contains('pasta') || lowerName.contains('cereal')) {
      return 'Grains';
    } else if (lowerName.contains('milk') || lowerName.contains('cheese') || 
               lowerName.contains('yogurt') || lowerName.contains('dairy')) {
      return 'Dairy';
    } else if (lowerName.contains('meat') || lowerName.contains('chicken') || 
               lowerName.contains('beef') || lowerName.contains('fish')) {
      return 'Proteins';
    } else {
      return 'Other';
    }
  }

  double _estimateItemCost(String name, double weightKg) {
    // Simple cost estimation based on item type and weight
    // These are rough estimates in AUD
    final category = _categorizeItem(name);
    final baseRatePerKg = switch (category) {
      'Fruits' => 4.0,
      'Vegetables' => 3.0,
      'Grains' => 2.5,
      'Dairy' => 6.0,
      'Proteins' => 15.0,
      _ => 5.0,
    };
    
    return max(0.5, weightKg * baseRatePerKg); // Minimum $0.50 per item
  }

  double _calculateTrend(List<FlSpot> points) {
    if (points.length < 2) return 0.0;
    
    final recent = points.sublist(points.length ~/ 2);
    final earlier = points.sublist(0, points.length ~/ 2);
    
    final recentAvg = recent.map((p) => p.y).reduce((a, b) => a + b) / recent.length;
    final earlierAvg = earlier.map((p) => p.y).reduce((a, b) => a + b) / earlier.length;
    
    return ((recentAvg - earlierAvg) / earlierAvg) * 100; // Percentage change
  }

  // === UI ====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Analytics'),
        elevation: 0,
        actions: [
          PopupMenuButton<WasteAnalysisPeriod>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Change time period',
            onSelected: (period) {
              setState(() {
                _selectedPeriod = period;
                _future = _loadAnalytics();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: WasteAnalysisPeriod.week,
                child: Text('Weekly'),
              ),
              const PopupMenuItem(
                value: WasteAnalysisPeriod.month,
                child: Text('Monthly'),
              ),
              const PopupMenuItem(
                value: WasteAnalysisPeriod.quarter,
                child: Text('Quarterly'),
              ),
              const PopupMenuItem(
                value: WasteAnalysisPeriod.year,
                child: Text('Yearly'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() => _future = _loadAnalytics()),
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: FutureBuilder<_WasteAnalytics>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load analytics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('${snap.error}'),
                  ],
                ),
              ),
            );
          }
          
          final data = snap.data!;
          final hasAnyData = data.totalItems > 0;

          if (!hasAnyData) {
            return const _EmptyState();
          }

          return Column(
            children: [
              // Summary Cards
              _WasteSummaryCards(data: data),
              
              // Tabbed Charts
              Expanded(
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelStyle: Theme.of(context).textTheme.labelMedium,
                        tabs: const [
                          Tab(icon: Icon(Icons.show_chart), text: 'Trends'),
                          Tab(icon: Icon(Icons.pie_chart), text: 'Categories'),
                          Tab(icon: Icon(Icons.bar_chart), text: 'Top Items'),
                          Tab(icon: Icon(Icons.schedule), text: 'Patterns'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _TrendsTab(data: data, period: _selectedPeriod),
                            _CategoriesTab(data: data),
                            _TopItemsTab(data: data),
                            _PatternsTab(data: data),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// === Enhanced Analytics Data Structure ====================================

class _WasteAnalytics {
  final List<String> periodLabels;
  final List<FlSpot> itemsPerPeriodSpots;
  final List<FlSpot> weightPerPeriodSpots;
  final List<FlSpot> costPerPeriodSpots;
  final List<MapEntry<String, int>> topItemsByCount;
  final List<MapEntry<String, double>> topItemsByValue;
  final List<PieChartSectionData> categoryData;
  final Map<int, int> timeOfDayData;
  final Map<int, int> dayOfWeekData;
  final int totalItems;
  final double totalWeight;
  final double totalEstimatedCost;
  final double averageItemsPerPeriod;
  final double wasteReductionTrend;

  _WasteAnalytics({
    required this.periodLabels,
    required this.itemsPerPeriodSpots,
    required this.weightPerPeriodSpots,
    required this.costPerPeriodSpots,
    required this.topItemsByCount,
    required this.topItemsByValue,
    required this.categoryData,
    required this.timeOfDayData,
    required this.dayOfWeekData,
    required this.totalItems,
    required this.totalWeight,
    required this.totalEstimatedCost,
    required this.averageItemsPerPeriod,
    required this.wasteReductionTrend,
  });
}

// === Enhanced Dashboard Components ========================================

class _WasteSummaryCards extends StatelessWidget {
  final _WasteAnalytics data;

  const _WasteSummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: 'Total Items',
              value: data.totalItems.toString(),
              subtitle: '${data.averageItemsPerPeriod.toStringAsFixed(1)} avg',
              icon: Icons.inventory_2,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: 'Total Weight',
              value: '${data.totalWeight.toStringAsFixed(1)}kg',
              subtitle: '~${(data.totalWeight / max(1, data.totalItems)).toStringAsFixed(1)}kg/item',
              icon: Icons.monitor_weight,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: 'Est. Cost',
              value: '\$${data.totalEstimatedCost.toStringAsFixed(0)}',
              subtitle: data.wasteReductionTrend >= 0 
                  ? '↗ ${data.wasteReductionTrend.toStringAsFixed(1)}%'
                  : '↘ ${data.wasteReductionTrend.abs().toStringAsFixed(1)}%',
              icon: Icons.attach_money,
              color: data.wasteReductionTrend >= 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// === Tab Components ======================================================

class _TrendsTab extends StatelessWidget {
  final _WasteAnalytics data;
  final WasteAnalysisPeriod period;

  const _TrendsTab({required this.data, required this.period});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Items Wasted Over Time',
          subtitle: 'Number of items discarded per ${period.name}',
          child: _MultiLineChart(
            labels: data.periodLabels,
            datasets: [
              _ChartDataset(
                name: 'Items',
                points: data.itemsPerPeriodSpots,
                color: Colors.red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Weight & Cost Analysis',
          subtitle: 'Weight (kg) and estimated cost (\$) trends',
          child: _MultiLineChart(
            labels: data.periodLabels,
            datasets: [
              _ChartDataset(
                name: 'Weight (kg)',
                points: data.weightPerPeriodSpots,
                color: Colors.blue,
              ),
              _ChartDataset(
                name: 'Cost (\$)',
                points: data.costPerPeriodSpots,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  final _WasteAnalytics data;

  const _CategoriesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Waste by Category',
          subtitle: 'Distribution of wasted items by food category',
          child: SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sections: data.categoryData,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._buildCategoryInsights(),
      ],
    );
  }

  List<Widget> _buildCategoryInsights() {
    final insights = [
      _InsightCard(
        icon: Icons.lightbulb_outline,
        title: 'Category Insights',
        content: 'Focus on the largest category to maximize waste reduction impact.',
        color: Colors.amber,
      ),
      _InsightCard(
        icon: Icons.eco,
        title: 'Sustainability Tip',
        content: 'Meal planning can reduce vegetable and fruit waste by up to 40%.',
        color: Colors.green,
      ),
    ];
    return insights;
  }
}

class _TopItemsTab extends StatelessWidget {
  final _WasteAnalytics data;

  const _TopItemsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Most Wasted Items',
          subtitle: 'Top 10 items by quantity',
          child: _TopItemsList(
            items: data.topItemsByCount,
            valueFormatter: (value) => '${value.toInt()} items',
            icon: Icons.numbers,
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Highest Value Waste',
          subtitle: 'Top 10 items by estimated cost',
          child: _TopItemsList(
            items: data.topItemsByValue,
            valueFormatter: (value) => '\$${value.toStringAsFixed(2)}',
            icon: Icons.attach_money,
          ),
        ),
      ],
    );
  }
}

class _PatternsTab extends StatelessWidget {
  final _WasteAnalytics data;

  const _PatternsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Time of Day Patterns',
          subtitle: 'When do you typically discard items?',
          child: _TimeOfDayChart(data: data.timeOfDayData),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Day of Week Patterns',
          subtitle: 'Which days see the most waste?',
          child: _DayOfWeekChart(data: data.dayOfWeekData),
        ),
        const SizedBox(height: 16),
        ..._buildPatternInsights(),
      ],
    );
  }

  List<Widget> _buildPatternInsights() {
    final peakHour = data.timeOfDayData.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final peakDay = data.dayOfWeekData.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return [
      _InsightCard(
        icon: Icons.schedule,
        title: 'Peak Waste Time',
        content: 'Most waste occurs around ${peakHour}:00. Consider checking food freshness at this time.',
        color: Colors.blue,
      ),
      _InsightCard(
        icon: Icons.calendar_today,
        title: 'Peak Waste Day',
        content: '${dayNames[peakDay - 1]} sees the most waste. Plan shopping accordingly.',
        color: Colors.purple,
      ),
    ];
  }
}

// === Supporting Widgets ===================================================

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MultiLineChart extends StatelessWidget {
  final List<String> labels;
  final List<_ChartDataset> datasets;

  const _MultiLineChart({
    required this.labels,
    required this.datasets,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = datasets
        .expand((d) => d.points)
        .map((p) => p.y)
        .fold<double>(4, max);

    return AspectRatio(
      aspectRatio: 1.6,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (labels.length - 1).toDouble(),
          minY: 0,
          maxY: maxY + (maxY * 0.1),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, maxY / 5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: max(1, maxY / 4),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: max(1, labels.length / 6),
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
          lineBarsData: datasets.map((dataset) => LineChartBarData(
            spots: dataset.points,
            isCurved: true,
            color: dataset.color,
            barWidth: 3,
            dotData: FlDotData(show: true),
          )).toList(),
        ),
      ),
    );
  }
}

class _ChartDataset {
  final String name;
  final List<FlSpot> points;
  final Color color;

  _ChartDataset({
    required this.name,
    required this.points,
    required this.color,
  });
}

class _TopItemsList extends StatelessWidget {
  final List<MapEntry<String, dynamic>> items;
  final String Function(dynamic) valueFormatter;
  final IconData icon;

  const _TopItemsList({
    required this.items,
    required this.valueFormatter,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: _getRankColor(index).withOpacity(0.2),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getRankColor(index),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.key,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                valueFormatter(item.value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getRankColor(index),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return Colors.amber;
      case 1: return Colors.grey;
      case 2: return Colors.brown;
      default: return Colors.blue;
    }
  }
}

class _TimeOfDayChart extends StatelessWidget {
  final Map<int, int> data;

  const _TimeOfDayChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.values.isEmpty ? 1 : data.values.reduce(max);
    
    return AspectRatio(
      aspectRatio: 2.0,
      child: BarChart(
        BarChartData(
          maxY: maxValue.toDouble() + 1,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: max(1, maxValue / 4),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                getTitlesWidget: (value, meta) {
                  final hour = value.toInt();
                  if (hour % 4 != 0) return const SizedBox();
                  return Text(
                    '${hour}:00',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(24, (hour) {
            return BarChartGroupData(
              x: hour,
              barRods: [
                BarChartRodData(
                  toY: (data[hour] ?? 0).toDouble(),
                  width: 8,
                  color: _getHourColor(hour),
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Color _getHourColor(int hour) {
    if (hour >= 6 && hour < 12) return Colors.orange; // Morning
    if (hour >= 12 && hour < 18) return Colors.blue; // Afternoon
    if (hour >= 18 && hour < 22) return Colors.green; // Evening
    return Colors.indigo; // Night
  }
}

class _DayOfWeekChart extends StatelessWidget {
  final Map<int, int> data;

  const _DayOfWeekChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxValue = data.values.isEmpty ? 1 : data.values.reduce(max);

    return AspectRatio(
      aspectRatio: 1.8,
      child: BarChart(
        BarChartData(
          maxY: maxValue.toDouble() + 1,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: max(1, maxValue / 4),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day < 1 || day > 7) return const SizedBox();
                  return Text(
                    dayNames[day - 1],
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(7, (index) {
            final day = index + 1;
            return BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: (data[day] ?? 0).toDouble(),
                  width: 30,
                  color: day >= 6 ? Colors.orange : Colors.blue, // Weekend vs weekday
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Waste Data Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging wasted items to see detailed analytics and insights here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.add),
              label: const Text('Log Waste Items'),
            ),
          ],
        ),
      ),
    );
  }
}