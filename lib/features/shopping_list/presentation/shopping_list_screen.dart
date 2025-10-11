import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/db/models/shopping_list_item.dart';
import '../domain/ingredient_category.dart';

class ShoppingListScreen extends StatefulWidget {
  final List<ShoppingListItem> shoppingList;
  final Function(ShoppingListItem) onToggleStatus;
  final Function(String) onDelete;
  final Function(ShoppingListItem, String) onSelectStore;
  final VoidCallback onRefresh;

  const ShoppingListScreen({
    super.key,
    required this.shoppingList,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onSelectStore,
    required this.onRefresh,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  @override
  Widget build(BuildContext context) {
    final totalItems = widget.shoppingList.length;
    final completedItems = widget.shoppingList
        .where((item) => item.status == ShoppingItemStatus.have)
        .length;
    final remainingItems = totalItems - completedItems;

    final itemsWithPrices =
        widget.shoppingList.where((item) => item.priceOptions.isNotEmpty).length;

    final estimatedCost = widget.shoppingList.fold<double>(0.0, (sum, item) {
      if (item.status == ShoppingItemStatus.buy && item.priceOptions.isNotEmpty) {
        final selectedPrice = item.priceOptions
            .firstWhere((p) => p.store == item.selectedStore,
                orElse: () => item.priceOptions.first)
            .price;
        return sum + (selectedPrice * item.quantity);
      }
      return sum;
    });

    // Group items by category
    final groupedItems = IngredientCategorizer.categorizeList<ShoppingListItem>(
      widget.shoppingList,
      (item) => item.name,
    );

    final sortedCategories = groupedItems.keys.toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Shopping List'),
            pinned: true,
            expandedHeight: 150.0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: widget.onRefresh,
                tooltip: 'Refresh Prices',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(
                totalItems,
                completedItems,
                remainingItems,
                estimatedCost,
                itemsWithPrices,
              ),
            ),
          ),
          if (widget.shoppingList.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Your shopping list is empty.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add items from recipes or manually.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sortedCategories.map((category) {
              final items = groupedItems[category]!;
              return SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverHeaderDelegate(
                        title: category.toString().split('.').last),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        return ShoppingListItemCard(
                          item: item,
                          onToggleStatus: widget.onToggleStatus,
                          onDelete: widget.onDelete,
                          onSelectStore: widget.onSelectStore,
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int remaining, double cost,
      int itemsWithPrices) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12.0,
            runSpacing: 12.0,
            children: [
              _HeaderItem(icon: Icons.list, label: 'Total Items', value: '$total'),
              _HeaderItem(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: '$completed'),
              _HeaderItem(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Remaining',
                  value: '$remaining'),
              _HeaderItem(
                  icon: Icons.attach_money,
                  label: 'Estimated Cost',
                  value: NumberFormat.currency(symbol: '\$').format(cost)),
              _HeaderItem(
                  icon: Icons.price_check,
                  label: 'Items with Prices',
                  value: '$itemsWithPrices/$total'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _SliverHeaderDelegate({required this.title});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 36.0;

  @override
  double get minExtent => 36.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class _HeaderItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class ShoppingListItemCard extends StatefulWidget {
  final ShoppingListItem item;
  final Function(ShoppingListItem) onToggleStatus;
  final Function(String) onDelete;
  final Function(ShoppingListItem, String) onSelectStore;

  const ShoppingListItemCard({
    super.key,
    required this.item,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onSelectStore,
  });

  @override
  State<ShoppingListItemCard> createState() => _ShoppingListItemCardState();
}

class _ShoppingListItemCardState extends State<ShoppingListItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final numberFormat = NumberFormat.decimalPattern();
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final bestPrice = item.priceOptions.isNotEmpty
        ? item.priceOptions.reduce((a, b) => a.price < b.price ? a : b)
        : null;
    
    final bool isHave = item.status == ShoppingItemStatus.have;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      color: isHave ? Colors.grey.shade300 : null,
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              value: isHave,
              onChanged: (value) => widget.onToggleStatus(item),
            ),
            title: Text(item.name,
                style: TextStyle(
                    decoration: isHave
                        ? TextDecoration.lineThrough
                        : null)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${numberFormat.format(item.quantity)} ${item.unit}'),
                if (item.fromRecipe != null)
                  Text('For: ${item.fromRecipe}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (bestPrice != null)
                  Row(
                    children: [
                      Text(currencyFormat.format(bestPrice.price),
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      if (bestPrice.special != null) ...[
                        const SizedBox(width: 8),
                        Text(bestPrice.special!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ],
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(bestPrice.store),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    ],
                  ),
              ],
            ),
            trailing: Radio<bool>(
              value: true,
              groupValue: _isExpanded,
              onChanged: (value) {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          if (_isExpanded && item.priceOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price Options:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...item.priceOptions.map((opt) {
                    final isSelected = item.selectedStore == opt.store;
                    return RadioListTile<String>(
                      title: Text(
                          '${opt.store}: ${currencyFormat.format(opt.price)}'),
                      subtitle: Text(opt.unitInfo),
                      value: opt.store,
                      groupValue: item.selectedStore,
                      onChanged: (store) {
                        widget.onSelectStore(item, store!);
                        setState(() {
                          _isExpanded = false;
                        });
                      },
                      secondary: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}