import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/db/models/shopping_list_item.dart';

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
        final itemCost = selectedPrice * item.quantity;
        print('Item: ${item.name}, Quantity: ${item.quantity}, Price: \$${selectedPrice.toStringAsFixed(2)}, Total: \$${itemCost.toStringAsFixed(2)}');
        return sum + itemCost;
      }
      return sum;
    });

    // Group items by category
    final groupedItems = <String, List<ShoppingListItem>>{};
    for (var item in widget.shoppingList) {
      (groupedItems[item.category] ??= []).add(item);
    }

    final sortedCategories = groupedItems.keys.toList()..sort();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Shopping List'),
            pinned: true,
            expandedHeight: 370.0,
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
                    delegate: _SliverHeaderDelegate(title: category),
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
    final progress = total > 0 ? completed / total : 0.0;
    
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 90, 16, 20),
      child: Column(
        children: [
          // Total Cost Card - Make it prominent
          Card(
            elevation: 3,
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Estimated Cost',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(cost),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (itemsWithPrices < total)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        '${total - itemsWithPrices} missing prices',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Progress Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Progress section
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shopping Progress',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completed of $total items completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.shopping_basket_outlined,
                          label: 'Remaining',
                          value: '$remaining',
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.check_circle_outline,
                          label: 'Completed',
                          value: '$completed',
                          color: Colors.green.shade600,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.price_check,
                          label: 'Priced',
                          value: '$itemsWithPrices',
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _SliverHeaderDelegate({required this.title});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getCategoryIcon(title),
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: theme.colorScheme.onSecondaryContainer,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'uncategorized':
        return Icons.category_outlined;
      case 'dairy':
        return Icons.local_drink_outlined;
      case 'meat':
        return Icons.set_meal_outlined;
      case 'produce':
      case 'fruits':
      case 'vegetables':
        return Icons.eco_outlined;
      case 'bakery':
        return Icons.bakery_dining_outlined;
      case 'frozen':
        return Icons.ac_unit_outlined;
      case 'pantry':
        return Icons.kitchen_outlined;
      case 'snacks':
        return Icons.cookie_outlined;
      case 'beverages':
        return Icons.local_cafe_outlined;
      default:
        return Icons.shopping_basket_outlined;
    }
  }

  @override
  double get maxExtent => 50.0;

  @override
  double get minExtent => 50.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
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

class _ShoppingListItemCardState extends State<ShoppingListItemCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final numberFormat = NumberFormat.decimalPattern();
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final theme = Theme.of(context);

    final bestPrice = item.priceOptions.isNotEmpty
        ? item.priceOptions.reduce((a, b) => a.price < b.price ? a : b)
        : null;

    final isCompleted = item.status == ShoppingItemStatus.have;
    final hasMultiplePrices = item.priceOptions.length > 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: isCompleted ? 1 : 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCompleted 
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : null,
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: isCompleted,
                  onChanged: (value) => widget.onToggleStatus(item),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              title: Text(
                item.name,
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${numberFormat.format(item.quantity)} ${item.unit}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (item.fromRecipe != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'For: ${item.fromRecipe}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (bestPrice != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              currencyFormat.format(bestPrice.price),
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              bestPrice.store,
                              style: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (bestPrice.special != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                bestPrice.special!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              trailing: hasMultiplePrices
                  ? IconButton(
                      icon: AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onPressed: _toggleExpansion,
                      tooltip: _isExpanded ? 'Hide price options' : 'Show price options',
                    )
                  : null,
            ),
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: hasMultiplePrices && item.priceOptions.isNotEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.store_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Choose Store:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...item.priceOptions.map((opt) {
                            final isSelected = item.selectedStore == opt.store;
                            final savings = bestPrice != null && opt.price > bestPrice.price
                                ? opt.price - bestPrice.price
                                : 0.0;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected 
                                    ? theme.colorScheme.primary 
                                    : theme.colorScheme.outline.withOpacity(0.5),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: isSelected 
                                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                                  : null,
                              ),
                              child: RadioListTile<String>(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                title: Row(
                                  children: [
                                    Text(
                                      opt.store,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      currencyFormat.format(opt.price),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: opt == bestPrice 
                                          ? Colors.green.shade700 
                                          : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    if (savings > 0) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '+${currencyFormat.format(savings)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: opt.unitInfo.isNotEmpty 
                                  ? Text(
                                      opt.unitInfo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : null,
                                value: opt.store,
                                groupValue: item.selectedStore,
                                onChanged: (store) {
                                  widget.onSelectStore(item, store!);
                                },
                                activeColor: theme.colorScheme.primary,
                              ),
                            );
                          }),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}