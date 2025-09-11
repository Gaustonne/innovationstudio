import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

enum InventoryPage { main, expired, wasted }

/// Global notifier to persist which page is active across routes.
final ValueNotifier<InventoryPage> activePageNotifier = ValueNotifier(
  InventoryPage.main,
);

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

class ExpiredItemsPage extends StatelessWidget {
  final List<Ingredient> items;
  final void Function(Ingredient) onAddDays;
  final void Function(Ingredient) onWaste;
  const ExpiredItemsPage({
    super.key,
    required this.items,
    required this.onAddDays,
    required this.onWaste,
  });

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _relativeExpiry(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) {
      final daysAgo = -diff;
      if (daysAgo == 0) return 'expired today';
      return 'expired ${daysAgo} day${daysAgo > 1 ? 's' : ''} ago';
    } else if (diff == 0) {
      return 'expires today';
    } else if (diff == 1) {
      return 'in 1 day';
    } else {
      return 'in $diff days';
    }
  }

  Color _expiryColor(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) return Colors.red;
    if (diff <= 2) return Colors.orange;
    return Colors.green;
  }

  Widget _buildItemCard(BuildContext context, Ingredient item) {
    final avatarText = item.name
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join();
    return Card(
      color: Colors.grey.shade100,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                avatarText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Quantity: ${item.quantity}'),
                      Text('Weight: ${item.weightKg} kg'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expiry: ${_formatDate(item.expiry)}'),
                          const SizedBox(height: 2),
                          Text(
                            _relativeExpiry(item.expiry),
                            style: TextStyle(
                              color: _expiryColor(item.expiry),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        key: const PageStorageKey('expiredList'),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Dismissible(
            key: ValueKey('${item.name}-${item.expiry.toIso8601String()}'),
            background: Container(
              color: Colors.green,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: const [
                  Icon(Icons.update, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Add 3 days', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Send to wasted', style: TextStyle(color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.delete_forever, color: Colors.white),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Right swipe: add 3 days to expiry
                onAddDays(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Extended "${item.name}" by 3 days')),
                );
                // Don't dismiss visually if we updated expiry (it may still be expired)
                return false;
              } else {
                // Left swipe: send to wasted
                final confirmed =
                    await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Send to wasted?'),
                        content: Text('Move "${item.name}" to wasted items?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirmed) {
                  onWaste(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Moved "${item.name}" to wasted items'),
                    ),
                  );
                  return true;
                }
                return false;
              }
            },
            child: _buildItemCard(context, item),
          );
        },
      ),
    );
  }
}

class WastedItemsPage extends StatelessWidget {
  final List<Ingredient> items;

  const WastedItemsPage({super.key, required this.items});

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _relativeExpiry(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) {
      final daysAgo = -diff;
      if (daysAgo == 0) return 'expired today';
      return 'expired ${daysAgo} day${daysAgo > 1 ? 's' : ''} ago';
    } else if (diff == 0) {
      return 'expires today';
    } else if (diff == 1) {
      return 'in 1 day';
    } else {
      return 'in $diff days';
    }
  }

  Color _expiryColor(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) return Colors.red;
    if (diff <= 2) return Colors.orange;
    return Colors.green;
  }

  Widget _buildItemCard(BuildContext context, Ingredient item) {
    final avatarText = item.name
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join();
    return Card(
      color: Colors.grey.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                avatarText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Quantity: ${item.quantity}'),
                      Text('Weight: ${item.weightKg} kg'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expiry: ${_formatDate(item.expiry)}'),
                          const SizedBox(height: 2),
                          Text(
                            _relativeExpiry(item.expiry),
                            style: TextStyle(
                              color: _expiryColor(item.expiry),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        key: const PageStorageKey('wastedList'),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildItemCard(context, items[index]),
      ),
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
  bool _showExpired = false;

  // Simple in-memory history of visited pages (top = current).
  final List<InventoryPage> _history = [InventoryPage.main];

  // Wasted items list (in-memory)
  final List<Ingredient> _wastedItems = [];

  // Dummy inventory data
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
      expiry: DateTime.now(),
    ),
    Ingredient(
      name: 'Milk',
      quantity: 1,
      weightKg: 1.0,
      expiry: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Ingredient(
      name: 'Butter',
      quantity: 1,
      weightKg: 0.25,
      expiry: DateTime.now().add(const Duration(days: 7)),
    ),
  ];

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _relativeExpiry(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) {
      final daysAgo = -diff;
      if (daysAgo == 0) return 'expired today';
      return 'expired ${daysAgo} day${daysAgo > 1 ? 's' : ''} ago';
    } else if (diff == 0) {
      return 'expires today';
    } else if (diff == 1) {
      return 'in 1 day';
    } else {
      return 'in $diff days';
    }
  }

  Color _expiryColor(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) return Colors.red;
    if (diff <= 2) return Colors.orange;
    return Colors.green;
  }

  bool _isExpired(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.isBefore(today);
  }

  List<Ingredient> _computeDisplayedItems() {
    final now = DateTime.now();

    var items = List<Ingredient>.from(_dummyItems);

    if (!_showExpired) {
      items = items.where((i) => !_isExpired(i.expiry)).toList();
    }

    if (_filterNext7Days) {
      final today = DateTime(now.year, now.month, now.day);
      final end = today.add(const Duration(days: 7));
      items = items.where((i) {
        final t = DateTime(i.expiry.year, i.expiry.month, i.expiry.day);
        return !t.isBefore(today) && !t.isAfter(end);
      }).toList();
    }

    if (_sortByExpiry) {
      items.sort((a, b) => a.expiry.compareTo(b.expiry));
    } else {
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    // ensure notifier reflects initial history
    activePageNotifier.value = _history.last;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _pushPage(InventoryPage page) {
    if (_history.isEmpty || _history.last != page) {
      _history.add(page);
    }
    activePageNotifier.value = page;
  }

  Widget _buildItemCard(
    BuildContext context,
    Ingredient item, {
    bool isExpiredView = false,
  }) {
    final avatarText = item.name
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join();
    return Card(
      color: isExpiredView ? Colors.grey.shade100 : null,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                avatarText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Quantity: ${item.quantity}'),
                      Text('Weight: ${item.weightKg} kg'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expiry: ${_formatDate(item.expiry)}'),
                          const SizedBox(height: 2),
                          Text(
                            _relativeExpiry(item.expiry),
                            style: TextStyle(
                              color: _expiryColor(item.expiry),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(
    BuildContext context, {
    required InventoryPage activePage,
  }) {
    final expiredCount = _dummyItems.where((i) => _isExpired(i.expiry)).length;
    final wastedCount = _wastedItems.length;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Inventory',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Main inventory'),
              selected: activePage == InventoryPage.main,
              onTap: () {
                _pushPage(InventoryPage.main);
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: Text('Expired items ($expiredCount)'),
              selected: activePage == InventoryPage.expired,
              onTap: () {
                _pushPage(InventoryPage.expired);
                Navigator.of(context).pop();
                _openExpiredPage(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: Text('Wasted items ($wastedCount)'),
              selected: activePage == InventoryPage.wasted,
              onTap: () {
                _pushPage(InventoryPage.wasted);
                Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('v1.0', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  void _openExpiredPage(BuildContext context) {
    final expiredItems = _dummyItems
        .where((i) => _isExpired(i.expiry))
        .toList();
    expiredItems.sort((a, b) => a.expiry.compareTo(b.expiry));
    _pushPage(InventoryPage.expired);
  }

  void _addDaysToItem(Ingredient item, int days) {
    setState(() {
      final idx = _dummyItems.indexWhere(
        (i) => i.name == item.name && i.expiry == item.expiry,
      );
      if (idx != -1) {
        final updated = Ingredient(
          name: item.name,
          quantity: item.quantity,
          weightKg: item.weightKg,
          expiry: item.expiry.add(Duration(days: days)),
        );
        _dummyItems[idx] = updated;
      }
    });
  }

  void _moveToWasted(Ingredient item) {
    setState(() {
      // remove first matching by name+expiry
      final idx = _dummyItems.indexWhere(
        (i) => i.name == item.name && i.expiry == item.expiry,
      );
      if (idx != -1) {
        final removed = _dummyItems.removeAt(idx);
        _wastedItems.insert(0, removed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _computeDisplayedItems();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end7 = today.add(const Duration(days: 7));
    final expiringCount = _dummyItems.where((i) {
      final t = DateTime(i.expiry.year, i.expiry.month, i.expiry.day);
      return !t.isBefore(today) && !t.isAfter(end7) && !_isExpired(i.expiry);
    }).length;
    final expiredCount = _dummyItems.where((i) => _isExpired(i.expiry)).length;

    final titleStyle = Theme.of(context).textTheme.displayMedium!.copyWith(
      color: Theme.of(context).colorScheme.onPrimary,
      fontSize: 24,
    );

    final expiredItems = _dummyItems.where((i) => _isExpired(i.expiry)).toList()
      ..sort((a, b) => a.expiry.compareTo(b.expiry));

    return PopScope(
      canPop: _history.length > 1,
      onPopInvokedWithResult: (didPop, result) {
        // If a pop was invoked, and we have history, consume it locally.
        if (_history.length > 1) {
          _history.removeLast();
          final prev = _history.isNotEmpty ? _history.last : InventoryPage.main;
          activePageNotifier.value = prev;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: ValueListenableBuilder<InventoryPage>(
            valueListenable: activePageNotifier,
            builder: (ctx, active, _) {
              final titleText = active == InventoryPage.main
                  ? 'Kitchen Inventory'
                  : active == InventoryPage.expired
                  ? 'Expired items'
                  : 'Wasted items';
              return Text(titleText, style: titleStyle);
            },
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          actions: [
            IconButton(
              tooltip: _sortByExpiry
                  ? 'Sort alphabetically'
                  : 'Sort by nearest expiry',
              icon: Icon(_sortByExpiry ? Icons.schedule : Icons.sort_by_alpha),
              onPressed: () => setState(() => _sortByExpiry = !_sortByExpiry),
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ],
        ),
        drawer: ValueListenableBuilder<InventoryPage>(
          valueListenable: activePageNotifier,
          builder: (ctx, active, _) => _buildDrawer(ctx, activePage: active),
        ),
        body: ValueListenableBuilder<InventoryPage>(
          valueListenable: activePageNotifier,
          builder: (context, active, _) {
            Widget child;
            if (active == InventoryPage.main) {
              child = Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        FilterChip(
                          label: Text(
                            'Expiring within 7 days ($expiringCount)',
                          ),
                          selected: _filterNext7Days,
                          onSelected: (v) =>
                              setState(() => _filterNext7Days = v),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Show expired ($expiredCount)'),
                          selected: _showExpired,
                          onSelected: (v) => setState(() => _showExpired = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 2),
                        Text(
                          'Showing ${displayed.length} of ${_dummyItems.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        key: const PageStorageKey('mainList'),
                        itemCount: displayed.length,
                        itemBuilder: (context, index) {
                          final item = displayed[index];
                          return Dismissible(
                            key: ValueKey(
                              '${item.name}-${item.expiry.toIso8601String()}',
                            ),
                            background: Container(
                              color: Colors.green,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.update, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add 3 days',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Send to wasted',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.delete_forever,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                _addDaysToItem(item, 3);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Extended "${item.name}" by 3 days',
                                    ),
                                  ),
                                );
                                return false;
                              } else {
                                final confirmed =
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Send to wasted?'),
                                        content: Text(
                                          'Move "${item.name}" to wasted items?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;

                                if (confirmed) {
                                  _moveToWasted(item);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Moved "${item.name}" to wasted items',
                                      ),
                                    ),
                                  );
                                  return true;
                                }
                                return false;
                              }
                            },
                            child: _buildItemCard(context, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            } else if (active == InventoryPage.expired) {
              child = ExpiredItemsPage(
                items: expiredItems,
                onAddDays: (item) => _addDaysToItem(item, 3),
                onWaste: (item) {
                  _moveToWasted(item);
                },
              );
            } else {
              child = WastedItemsPage(items: _wastedItems);
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: SizedBox(key: ValueKey(active), child: child),
            );
          },
        ),
      ),
    );
  }
}
