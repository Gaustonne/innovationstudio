import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class Ingredient {
  final String name;
  final int quantity;
  final double weightKg;
  final DateTime expiry;

  Ingredient({
    required this.name,
    required this.quantity,
    required this.weightKg,
    required this.expiry,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitchen Inventory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const InventoryHomePage(),
    );
  }
}

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key});

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  bool _sortByExpiry = false;
  bool _filterNext7Days = false;

  // Dummy inventory data for now
  final List<Ingredient> _dummyItems = [
    Ingredient(
      name: 'All-purpose Flour',
      quantity: 2,
      weightKg: 1.0,
      expiry: DateTime.now().add(const Duration(days: 365)),
    ),
    Ingredient(
      name: 'Sugar',
      quantity: 1,
      weightKg: 0.5,
      expiry: DateTime.now().add(const Duration(days: 400)),
    ),
    Ingredient(
      name: 'Eggs',
      quantity: 12,
      weightKg: 0.72,
      expiry: DateTime.now().add(const Duration(days: 7)),
    ),
    Ingredient(
      name: 'Milk',
      quantity: 1,
      weightKg: 1.0,
      expiry: DateTime.now().add(const Duration(days: 5)),
    ),
    Ingredient(
      name: 'Butter',
      quantity: 1,
      weightKg: 0.25,
      expiry: DateTime.now().add(const Duration(days: 60)),
    ),
  ];

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  List<Ingredient> _computeDisplayedItems() {
    final now = DateTime.now();
    final next7 = now.add(const Duration(days: 7));

    var items = List<Ingredient>.from(_dummyItems);

    if (_filterNext7Days) {
      items = items
          .where((i) => i.expiry.isAfter(now) && i.expiry.isBefore(next7))
          .toList();
    }

    if (_sortByExpiry) {
      items.sort((a, b) => a.expiry.compareTo(b.expiry));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _computeDisplayedItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Inventory'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            tooltip: _sortByExpiry ? 'Unsort' : 'Sort by nearest expiry',
            icon: Icon(_sortByExpiry ? Icons.sort_by_alpha : Icons.schedule),
            onPressed: () => setState(() => _sortByExpiry = !_sortByExpiry),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                FilterChip(
                  label: const Text('Expiring in 7 days'),
                  selected: _filterNext7Days,
                  onSelected: (v) => setState(() => _filterNext7Days = v),
                ),
                const SizedBox(width: 12),
                Text('Showing ${displayed.length} of ${_dummyItems.length}'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: displayed.length,
                itemBuilder: (context, index) {
                  final item = displayed[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            child: Text(
                              item.name
                                  .split(' ')
                                  .map((s) => s[0])
                                  .take(2)
                                  .join(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    Text('Quantity: ${item.quantity}'),
                                    Text('Weight: ${item.weightKg} kg'),
                                    Text('Expiry: ${_formatDate(item.expiry)}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // optional chevron
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
