import '../../shopping_list/presentation/shopping_list_screen.dart';
import '../../recipes/presentation/recipe_screen.dart';
import '../../../common/services/pricing_service.dart';
import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';

import '../../../common/db/models/ingredient.dart';
import '../../../common/db/collections/inventory_store.dart';
import '../../../common/db/collections/wasted_store.dart';
import '../../../common/db/collections/shopping_list_store.dart';
import '../../../common/db/models/shopping_list_item.dart';
import '../../../common/widgets/navigation/drawer.dart';
import '../../../common/storage/preferences.dart';
import 'expired.dart';
import 'wasted.dart';
import 'item_card.dart';
import 'add_item.dart';

enum InventoryPage { main, expired, wasted, recipes, shoppingList }

/// Global notifier to persist which page is active across routes.
final ValueNotifier<InventoryPage> activePageNotifier = ValueNotifier(
  InventoryPage.main,
);

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
  
  // Shopping list items (in-memory)
  final List<ShoppingListItem> _shoppingList = [];

  // Stores
  final InventoryStore _inventoryStore = InventoryStore();
  final WastedStore _wastedStore = WastedStore();
  final ShoppingListStore _shoppingListStore = ShoppingListStore();
  final PricingService _pricingService = PricingService();

  // In-memory view of inventory (single source-of-truth for UI)
  List<Ingredient> _items = [];

  // Preferences
  String? _username;

  bool _isExpired(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.isBefore(today);
  }

  List<Ingredient> _computeDisplayedItems() {
    final now = DateTime.now();

    var items = List<Ingredient>.from(_items);

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
    // load persisted data
    _loadData();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = PreferencesService();
    final name = await prefs.getUsername();
    setState(() => _username = name);
  }

  Future<void> _loadData({bool fetchPrices = false}) async {
    final inv = await _inventoryStore.getAll();
    final wasted = await _wastedStore.getAll();
    final shopping = await _shoppingListStore.getAll();

    if (fetchPrices) {
      for (var i = 0; i < shopping.length; i++) {
        final item = shopping[i];
        if (item.status == ShoppingItemStatus.buy) {
          final prices = await _pricingService.getPriceOptions(item.name);
          shopping[i] = item.copyWith(
            priceOptions: prices,
            selectedStore: item.selectedStore ?? (prices.isNotEmpty ? prices.first.store : null),
          );
          await _shoppingListStore.update(shopping[i]);
        }
      }
    }

    // Use persisted data as single source of truth. Tests can populate DB beforehand.
    setState(() {
      _items = inv;
      _wastedItems.clear();
      _wastedItems.addAll(wasted);
      _shoppingList.clear();
      _shoppingList.addAll(shopping);
    });
  }

  void _pushPage(InventoryPage page) {
    if (_history.isEmpty || _history.last != page) {
      _history.add(page);
    }
    activePageNotifier.value = page;
  }

  Future<void> _addDaysToItem(Ingredient item, int days) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      final updated = item.copyWith(
        expiry: item.expiry.add(Duration(days: days)),
      );
      setState(() => _items[idx] = updated);
      // persist change
      await _inventoryStore.update(updated);
    }
  }

  Future<void> _handleBarcodeScanner() async {
    final result = await Navigator.of(context).push<BarcodeScannerResult>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (result == null) return;

    // If we have a suggested ingredient from barcode lookup, use it
    if (result.suggestedIngredient != null) {
      _handleAddOrEditFromScreen(existing: result.suggestedIngredient);
    } else {
      // Manual entry fallback
      _handleAddOrEditFromScreen();
    }
  }

  Future<void> _handleAddOrEditFromScreen({Ingredient? existing}) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => AddIngredientScreen(ingredient: existing),
      ),
    );

    if (result == null) return;

    // Editor returns EditResult (saved or deleted)
    if (result is EditResult) {
      if (result.deletedId != null) {
        // remove from in-memory and DB
        final idx = _items.indexWhere((i) => i.id == result.deletedId);
        if (idx != -1) setState(() => _items.removeAt(idx));
        await _inventoryStore.delete(result.deletedId!);
        return;
      }

      final saved = result.item!;
      final idx = _items.indexWhere((i) => i.id == saved.id);
      if (idx != -1) {
        // update
        setState(() => _items[idx] = saved);
        await _inventoryStore.update(saved);
      } else {
        // insert
        await _inventoryStore.insert(saved);
        setState(() => _items.insert(0, saved));
      }
    } else if (result is Ingredient) {
      // backwards-compat if editor returned Ingredient
      final idx = _items.indexWhere((i) => i.id == result.id);
      if (idx != -1) {
        setState(() => _items[idx] = result);
        await _inventoryStore.update(result);
      } else {
        await _inventoryStore.insert(result);
        setState(() => _items.insert(0, result));
      }
    }
  }

  Future<void> _moveToWasted(Ingredient item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      final removed = _items.removeAt(idx);
      setState(() {
        _wastedItems.insert(0, removed);
      });
      // persist change: remove from inventory and add to wasted
      await _inventoryStore.delete(removed.id);
      await _wastedStore.insert(removed, movedAt: DateTime.now());
    }
  }

  /// Debug helper: clear and seed the application database with sample items.
  Future<void> _seedDatabase() async {
    // Clear both tables
    final existing = await _inventoryStore.getAll();
    for (final e in existing) {
      await _inventoryStore.delete(e.id);
    }
    final existingW = await _wastedStore.getAll();
    for (final w in existingW) {
      await _wastedStore.delete(w.id);
    }

    // Insert sample inventory
    final now = DateTime.now();
    final samples = [
      Ingredient(
        name: 'Tomato',
        quantity: 5,
        weightKg: 1.2,
        expiry: now.add(const Duration(days: 14)),
      ),
      Ingredient(
        name: 'Lettuce',
        quantity: 2,
        weightKg: 0.5,
        expiry: now.add(const Duration(days: 21)),
      ),
      Ingredient(
        name: 'Milk',
        quantity: 1,
        weightKg: 1.0,
        expiry: now.add(const Duration(days: 2)),
      ),
      Ingredient(
        name: 'Cheese',
        quantity: 1,
        weightKg: 1.0,
        expiry: now.subtract(const Duration(days: 1)),
      ),
      Ingredient(
        name: 'Eggs',
        quantity: 12,
        weightKg: 0.7,
        expiry: now.subtract(const Duration(days: 5)),
      ),
    ];

    for (final s in samples) {
      await _inventoryStore.insert(s);
    }

    // Move one item to wasted for example
    final moved = samples.last;
    await _inventoryStore.delete(moved.id);
    await _wastedStore.insert(moved, movedAt: DateTime.now());

    final prefs = PreferencesService();
    await prefs.clear(); // clear existing prefs
    await prefs.setUsername('Test User');

    // Reload into memory and refresh UI
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _computeDisplayedItems();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end7 = today.add(const Duration(days: 7));
    final expiringCount = _items.where((i) {
      final t = DateTime(i.expiry.year, i.expiry.month, i.expiry.day);
      return !t.isBefore(today) && !t.isAfter(end7) && !_isExpired(i.expiry);
    }).length;
    final expiredCount = _items.where((i) => _isExpired(i.expiry)).length;

    final titleStyle = Theme.of(context).textTheme.displayMedium!.copyWith(
      color: Theme.of(context).colorScheme.onPrimary,
      fontSize: 24,
    );

    final expiredItems = _items.where((i) => _isExpired(i.expiry)).toList()
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
                  : active == InventoryPage.wasted
                  ? 'Wasted items'
                  : active == InventoryPage.recipes
                  ? 'Recipes'
                  : 'Shopping List';
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
          builder: (ctx, active, _) => AppDrawer(
            activePage: active,
            expiredCount: expiredCount,
            wastedCount: _wastedItems.length,
            username: _username,
            onMain: () {
              _pushPage(InventoryPage.main);
              Navigator.of(ctx).pop();
              Navigator.of(ctx).popUntil((route) => route.isFirst);
            },
            onExpired: () {
              _pushPage(InventoryPage.expired);
              Navigator.of(ctx).pop();
            },
            onWasted: () {
              _pushPage(InventoryPage.wasted);
              Navigator.of(ctx).pop();
            },
            onRecipes: () {
              _pushPage(InventoryPage.recipes);
              Navigator.of(ctx).pop();
            },
            onShoppingList: () {
              _pushPage(InventoryPage.shoppingList);
              Navigator.of(ctx).pop();
            },
            onSeed: () async {
              Navigator.of(ctx).pop();
              // confirm (capture messenger before await)
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('Seed database?'),
                  content: const Text(
                    'This will replace the app DB with sample data.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dctx).pop(true),
                      child: const Text('Seed'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _seedDatabase();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Database seeded')),
                );
              }
            },
          ),
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
                        Text('Showing ${displayed.length} of ${_items.length}'),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _handleBarcodeScanner(),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Barcode'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            _pushPage(InventoryPage.recipes);
                          },
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('Find Recipes'),
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
                            key: ValueKey(item.id),
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
                                // Capture messenger before awaiting dialog
                                final messenger = ScaffoldMessenger.of(context);
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
                                  messenger.showSnackBar(
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
                            child: InkWell(
                              onTap: () =>
                                  _handleAddOrEditFromScreen(existing: item),
                              child: ItemCard(item: item),
                            ),
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
                onEdit: (item) => _handleAddOrEditFromScreen(existing: item),
              );
            } else if (active == InventoryPage.wasted) {
              child = WastedItemsPage(items: _wastedItems);
            } else if (active == InventoryPage.recipes) {
              child = RecipeScreen(
                userIngredients: _items,
                onShoppingListUpdated: () => _loadData(fetchPrices: true),
              );
            } else if (active == InventoryPage.shoppingList) {
              child = ShoppingListScreen(
                shoppingList: _shoppingList,
                onToggleStatus: (item) async {
                  final updated = item.copyWith(
                    status: item.status == ShoppingItemStatus.buy
                        ? ShoppingItemStatus.have
                        : ShoppingItemStatus.buy,
                  );
                  await _shoppingListStore.update(updated);
                  _loadData();
                },
                onDelete: (id) async {
                  await _shoppingListStore.delete(id);
                  _loadData();
                },
                onSelectStore: (item, store) async {
                  final updated = item.copyWith(selectedStore: store);
                  await _shoppingListStore.update(updated);
                  _loadData();
                },
                onRefresh: () => _loadData(fetchPrices: true),
              );
            } else {
              child = Container();
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: SizedBox(key: ValueKey(active), child: child),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _handleAddOrEditFromScreen(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
