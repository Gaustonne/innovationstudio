import 'package:flutter/material.dart';
import '../../models/shopping_list_item.dart';
import '../../models/recipe.dart';
import '../../models/pantry_item.dart';
import '../../services/shopping_list_service.dart';
import '../../services/supermarket_api_service.dart';

class ShoppingListPage extends StatefulWidget {
  final List<Recipe> recipes;
  final List<PantryItem> pantryItems;

  const ShoppingListPage({
    super.key,
    this.recipes = const [],
    this.pantryItems = const [],
  });

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  List<ShoppingListItem> _shoppingItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateShoppingList();
  }

  void _generateShoppingList() async {
    setState(() {
      _isLoading = true;
    });

    // Generate shopping list from recipes and pantry with prices
    final generatedItems = await ShoppingListService.generateShoppingList(
      recipes: widget.recipes,
      pantryItems: widget.pantryItems,
      includePrices: true,
    );

    setState(() {
      _shoppingItems = generatedItems;
      _isLoading = false;
    });
  }

  void _toggleItemStatus(int index) {
    setState(() {
      _shoppingItems[index] = _shoppingItems[index].toggleStatus();
    });
  }

  void _clearCompleted() {
    setState(() {
      _shoppingItems.removeWhere(
        (item) => item.status == ShoppingListStatus.have,
      );
    });
  }

  void _showSupermarketComparison() {
    final supermarketTotals = ShoppingListService.calculateSupermarketTotals(_shoppingItems);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supermarket Price Comparison'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (supermarketTotals.isEmpty)
                const Text('No price data available for comparison.')
              else ...[
                const Text(
                  'Total cost at each supermarket for remaining items:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                ...supermarketTotals.entries.map((entry) {
                  final supermarket = entry.key;
                  final total = entry.value;
                  final isLowest = total == supermarketTotals.values.reduce((a, b) => a < b ? a : b);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLowest ? Colors.green.withOpacity(0.1) : null,
                      border: Border.all(
                        color: isLowest ? Colors.green : Colors.grey[300]!,
                        width: isLowest ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getSupermarketColor(supermarket),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            supermarket.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isLowest ? Colors.green : null,
                          ),
                        ),
                        if (isLowest) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.star, color: Colors.green, size: 20),
                        ],
                      ],
                    ),
                  );
                }),
                if (supermarketTotals.length > 1) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Potential savings: \$${(supermarketTotals.values.reduce((a, b) => a > b ? a : b) - supermarketTotals.values.reduce((a, b) => a < b ? a : b)).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = ShoppingListService.calculateStats(_shoppingItems);
    final groupedItems = ShoppingListService.groupByCategory(_shoppingItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_shoppingItems.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'clear':
                    _clearCompleted();
                    break;
                  case 'compare':
                    _showSupermarketComparison();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear Completed'),
                ),
                const PopupMenuItem(
                  value: 'regenerate',
                  child: Text('Regenerate List'),
                ),
                const PopupMenuItem(
                  value: 'compare',
                  child: Text('Compare Supermarkets'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shoppingItems.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildStatsCard(stats),
                    Expanded(
                      child: ListView.builder(
                        itemCount: groupedItems.keys.length,
                        itemBuilder: (context, categoryIndex) {
                          final category = groupedItems.keys.elementAt(categoryIndex);
                          final items = groupedItems[category]!;
                          return _buildCategorySection(category, items);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _shoppingItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _generateShoppingList,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No items to shop for!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some recipes to your plan to generate a shopping list.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to recipe selection or meal planning
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recipe planning feature coming soon!')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Recipes'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ShoppingListStats stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Items',
                  stats.totalItems.toString(),
                  Icons.list,
                ),
                _buildStatItem(
                  'Completed',
                  stats.checkedItems.toString(),
                  Icons.check_circle,
                  color: Colors.green,
                ),
                _buildStatItem(
                  'Remaining',
                  stats.uncheckedItems.toString(),
                  Icons.shopping_cart,
                  color: Colors.orange,
                ),
              ],
            ),
            if (stats.estimatedCost > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Estimated Cost',
                    '\$${stats.estimatedCost.toStringAsFixed(2)}',
                    Icons.attach_money,
                    color: Colors.blue,
                  ),
                  _buildStatItem(
                    'Items with Prices',
                    '${stats.itemsWithPrices}/${stats.totalItems}',
                    Icons.local_offer,
                    color: Colors.purple,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<ShoppingListItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Text(
            category.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final index = _shoppingItems.indexOf(entry.value);
          return _buildShoppingListItem(entry.value, index);
        }),
      ],
    );
  }

  Widget _buildShoppingListItem(ShoppingListItem item, int index) {
    final isChecked = item.status == ShoppingListStatus.have;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 1,
      child: ExpansionTile(
        leading: Checkbox(
          value: isChecked,
          onChanged: (_) => _toggleItemStatus(index),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayQuantity,
              style: TextStyle(
                color: isChecked ? Colors.grey : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (item.selectedPrice != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    item.displayPriceWithSpecial,
                    style: TextStyle(
                      color: item.hasSpecialOffer ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.selectedPrice != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getSupermarketColor(item.selectedPrice!.supermarket),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.selectedPrice!.supermarketName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (item.sourceRecipes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'For: ${item.sourceRecipes.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        trailing: isChecked 
          ? Icon(Icons.check_circle, color: Colors.green)
          : Icon(Icons.circle_outlined, color: Colors.grey[400]),
        children: item.availablePrices.length > 1 
          ? [_buildPriceOptions(item, index)]
          : [],
        onExpansionChanged: null, // Allow expansion only if there are price options
      ),
    );
  }

  Widget _buildPriceOptions(ShoppingListItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Options:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...item.availablePrices.map((price) {
            final isSelected = price == item.selectedPrice;
            final packsNeeded = (item.quantity / price.packageSize).ceil();
            final totalCost = price.price * packsNeeded;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? Colors.blue.withOpacity(0.1) : null,
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSupermarketColor(price.supermarket),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    price.supermarketName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  price.productName,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${price.price.toStringAsFixed(2)} × $packsNeeded = \$${totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (price.onSpecial) ...[
                      Text(
                        'Special: ${price.specialOffer}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                onTap: () {
                  setState(() {
                    _shoppingItems[index] = item.selectPrice(price);
                  });
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getSupermarketColor(Supermarket supermarket) {
    switch (supermarket) {
      case Supermarket.woolworths:
        return Colors.green;
      case Supermarket.coles:
        return Colors.red;
      case Supermarket.iga:
        return Colors.orange;
      case Supermarket.aldi:
        return Colors.blue;
    }
  }
}