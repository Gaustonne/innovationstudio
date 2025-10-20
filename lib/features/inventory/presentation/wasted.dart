import 'package:flutter/material.dart';
import '../../../common/services/app_events.dart';

import '../../../common/db/collections/wasted_store.dart';
import '../../../common/db/models/wasted_item.dart';
import '../../../common/db/collections/inventory_store.dart';
// import '../../../common/db/models/wasted_item_extension.dart'; // toIngredient()
import '../../wasted/presentation/waste_log_form.dart';

enum _SortMode { newestFirst, valueHighLow, nameAZ }

class WastedItemsPage extends StatefulWidget {
  const WastedItemsPage({super.key, required this.items});
  // Kept only for legacy callers; not used anymore.
  final List<dynamic> items;

  @override
  State<WastedItemsPage> createState() => _WastedItemsPageState();
}

class _WastedItemsPageState extends State<WastedItemsPage> {
  WasteWeeklySummary? _weekly;
  List<WastedItem> _all = [];
  List<WastedItem> _displayed = [];

  String? _reasonFilter;
  _SortMode _sortMode = _SortMode.newestFirst;

  static const _reasons = [
    'Expired',
    'Spoiled',
    'Leftovers',
    'Overbought',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    await Future.wait([_reloadList(), _loadWeekly()]);
  }

  Future<void> _loadWeekly() async {
    final summary = await WastedStore().getWeeklySummary();
    if (!mounted) return;
    setState(() => _weekly = summary);
  }

  Future<void> _reloadList() async {
    final recent = await WastedStore().listRecent(limit: 500);
    if (!mounted) return;
    setState(() {
      _all = recent;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var list = _reasonFilter == null
        ? List<WastedItem>.from(_all)
        : _all
              .where(
                (w) =>
                    (w.reason ?? '').toLowerCase() ==
                    _reasonFilter!.toLowerCase(),
              )
              .toList();

    switch (_sortMode) {
      case _SortMode.newestFirst:
        list.sort((a, b) => b.movedAt.compareTo(a.movedAt));
        break;
      case _SortMode.valueHighLow:
        list.sort((a, b) => (b.estValue ?? 0).compareTo(a.estValue ?? 0));
        break;
      case _SortMode.nameAZ:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }

    _displayed = list;
  }

  // ---- inventory quantity deltas ------------------------------------------

  /// Applies a quantity delta to the matching inventory item by **name**.
  /// If no item exists and [delta] > 0 (i.e., we’re restoring), we insert one
  /// using the wasted row’s details (preserves `origExpiry` via toIngredient()).
  Future<void> _applyInventoryDeltaFor(
    WastedItem w, {
    required int delta,
  }) async {
    final invStore = InventoryStore();
    final inv = await invStore.getAll();

    final idx = inv.indexWhere(
      (i) => i.name.toLowerCase().trim() == w.name.toLowerCase().trim(),
    );

    if (idx == -1) {
      // Not found: only insert on positive delta (undo)
      if (delta > 0) {
        await invStore.insert(w.toIngredient());
      }
      return;
    }

    final current = inv[idx];
    final newQty = current.quantity + delta; // delta can be negative

    if (newQty <= 0) {
      await invStore.delete(current.id);
    } else {
      await invStore.update(current.copyWith(quantity: newQty));
    }
  }

  // ---- actions -------------------------------------------------------------

  Future<void> _openLogWaste() async {
    final res = await showDialog(
      context: context,
      builder: (_) => const WasteLogForm(),
    );
    if (res is! WasteLogResult) return;

    // Only allow logging if the item exists in inventory (as you requested).
    final inventory = await InventoryStore().getAll();
    final existsInInventory = inventory.any(
      (i) => i.name.toLowerCase().trim() == res.item.name.toLowerCase().trim(),
    );
    if (!existsInInventory) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can only log waste for items that exist in your inventory.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 1) Insert into wasted
    await WastedStore().insertManual(res.item);

    // 2) Decrement inventory quantity
    final dec = (res.item.quantity ?? 1).round();
    await _applyInventoryDeltaFor(res.item, delta: -dec);

    // 3) Refresh this screen & notify inventory screen to reload
    if (!mounted) return;
    await _reloadAll();
    AppEvents.instance.requestReloadAll();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Logged: ${res.item.name}')));
  }

  Future<void> _restoreToInventory(WastedItem item) async {
    try {
      // 1) Increase inventory quantity (or insert if missing)
      final inc = (item.quantity ?? 1).round();
      await _applyInventoryDeltaFor(item, delta: inc);

      // 2) Remove from wasted
      await WastedStore().delete(item.id);

      // 3) Refresh this screen & notify inventory screen to reload
      if (!mounted) return;
      await _reloadAll();
      AppEvents.instance.requestReloadAll();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored "${item.name}" to inventory')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error restoring item: $e')));
      }
    }
  }

  void _setReasonFilter(String? reason) {
    setState(() {
      _reasonFilter = reason;
      _applyFilters();
    });
  }

  void _setSortMode(_SortMode mode) {
    setState(() {
      _sortMode = mode;
      _applyFilters();
    });
  }

  Widget _chip(String label, String? value) {
    final selected = _reasonFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setReasonFilter(selected ? null : value),
      ),
    );
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasted items'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reloadAll,
          ),
          PopupMenuButton<_SortMode>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sortMode,
            onSelected: _setSortMode,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SortMode.newestFirst,
                child: Text('Newest → Oldest'),
              ),
              PopupMenuItem(
                value: _SortMode.valueHighLow,
                child: Text('Highest \$ → Lowest \$'),
              ),
              PopupMenuItem(value: _SortMode.nameAZ, child: Text('Name A → Z')),
            ],
          ),
        ],
      ),

      // Move FAB slightly left
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 65.0),
        child: Align(
          alignment: Alignment.bottomRight,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Log waste'),
            onPressed: _openLogWaste,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            if (_weekly != null)
              Material(
                color: theme.colorScheme.surfaceVariant.withOpacity(.5),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_view_week_outlined),
                      const SizedBox(width: 8),
                      Text('Last 7 days: ${_weekly!.itemCount} discarded'),
                      const Spacer(),
                      Text('\$${_weekly!.totalValue.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('All', null),
                    for (final r in _reasons) _chip(r, r),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _displayed.isEmpty
                  ? const Center(child: Text('No wasted items yet'))
                  : RefreshIndicator(
                      onRefresh: _reloadAll,
                      child: ListView.separated(
                        key: const PageStorageKey('wastedList'),
                        itemCount: _displayed.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          final w = _displayed[i];
                          final parts = <String>[];
                          if (w.quantity != null)
                            parts.add('${w.quantity} ${w.unit ?? ''}'.trim());
                          if ((w.reason ?? '').isNotEmpty)
                            parts.add('Reason: ${w.reason}');
                          parts.add(
                            'When: ${w.movedAt.toLocal().toString().split(".").first}',
                          );

                          return ListTile(
                            leading: const Icon(Icons.delete_outline),
                            title: Text(w.name),
                            subtitle: Text(parts.join(' • ')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (w.estValue != null)
                                  Text('\$${w.estValue!.toStringAsFixed(2)}'),
                                IconButton(
                                  tooltip: 'Undo (restore to inventory)',
                                  icon: const Icon(Icons.undo_outlined),
                                  onPressed: () => _restoreToInventory(w),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
