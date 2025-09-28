import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../models/recipe.dart';
import '../models/shopping_list_item.dart';
import 'supermarket_api_service.dart';

class ShoppingListService {
  /// Generate shopping list from recipes, merging ingredients and subtracting pantry items
  static Future<List<ShoppingListItem>> generateShoppingList({
    required List<Recipe> recipes,
    required List<PantryItem> pantryItems,
    bool includePrices = true,
  }) async {
    final Map<String, Ingredient> mergedIngredients = {};
    final Map<String, List<String>> ingredientSources = {};

    // Step 1: Merge ingredients from all recipes
    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        final key = '${ingredient.name.toLowerCase()}_${ingredient.unit.toLowerCase()}';
        
        if (mergedIngredients.containsKey(key)) {
          // Merge with existing ingredient
          final existing = mergedIngredients[key]!;
          mergedIngredients[key] = existing.copyWith(
            quantity: existing.quantity + ingredient.quantity,
          );
          ingredientSources[key]!.add(recipe.name);
        } else {
          // Add new ingredient
          mergedIngredients[key] = ingredient;
          ingredientSources[key] = [recipe.name];
        }
      }
    }

    // Step 2: Subtract available pantry items
    final Map<String, double> neededQuantities = {};
    
    for (final entry in mergedIngredients.entries) {
      final key = entry.key;
      final ingredient = entry.value;
      double neededQuantity = ingredient.quantity;

      // Find matching pantry items
      for (final pantryItem in pantryItems) {
        final pantryKey = '${pantryItem.name.toLowerCase()}_${pantryItem.unit.toLowerCase()}';
        if (pantryKey == key) {
          // Subtract available quantity
          final availableQuantity = pantryItem.quantity;
          neededQuantity = (neededQuantity - availableQuantity).clamp(0.0, double.infinity);
          break; // Use only the first matching pantry item
        }
      }

      neededQuantities[key] = neededQuantity;
    }

    // Step 3: Create shopping list items with pack rounding and price fetching
    final List<ShoppingListItem> shoppingList = [];
    
    for (final entry in mergedIngredients.entries) {
      final key = entry.key;
      final ingredient = entry.value;
      final neededQuantity = neededQuantities[key]!;
      
      if (neededQuantity > 0) {
        // Create ingredient with needed quantity
        final adjustedIngredient = ingredient.copyWith(quantity: neededQuantity);
        
        // Fetch prices if requested
        List<ProductPrice> availablePrices = [];
        if (includePrices) {
          try {
            availablePrices = await SupermarketApiService.searchProductPrices(ingredient.name);
          } catch (e) {
            // Continue without prices if API fails
            print('Failed to fetch prices for ${ingredient.name}: $e');
          }
        }
        
        final shoppingItem = ShoppingListItem.fromIngredient(
          adjustedIngredient,
          sourceRecipes: ingredientSources[key] ?? [],
          availablePrices: availablePrices,
        );
        shoppingList.add(shoppingItem);
      }
    }

    // Step 4: Sort by category and name
    shoppingList.sort((a, b) {
      final categoryComparison = a.category.compareTo(b.category);
      if (categoryComparison != 0) return categoryComparison;
      return a.name.compareTo(b.name);
    });

    return shoppingList;
  }

  /// Update pantry items after shopping (add purchased items)
  static List<PantryItem> updatePantryAfterShopping({
    required List<PantryItem> currentPantry,
    required List<ShoppingListItem> purchasedItems,
  }) {
    final updatedPantry = List<PantryItem>.from(currentPantry);

    for (final item in purchasedItems) {
      if (item.status == ShoppingListStatus.have) {
        // Find existing pantry item or create new one
        final existingIndex = updatedPantry.indexWhere(
          (pantryItem) => 
            pantryItem.name.toLowerCase() == item.name.toLowerCase() &&
            pantryItem.unit.toLowerCase() == item.unit.toLowerCase(),
        );

        if (existingIndex != -1) {
          // Update existing item
          final existing = updatedPantry[existingIndex];
          updatedPantry[existingIndex] = existing.copyWith(
            quantity: existing.quantity + item.totalQuantity,
          );
        } else {
          // Add new pantry item
          final newPantryItem = PantryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: item.name,
            quantity: item.totalQuantity,
            unit: item.unit,
            category: item.category,
          );
          updatedPantry.add(newPantryItem);
        }
      }
    }

    return updatedPantry;
  }

  /// Get shopping list grouped by category
  static Map<String, List<ShoppingListItem>> groupByCategory(
    List<ShoppingListItem> items,
  ) {
    final Map<String, List<ShoppingListItem>> grouped = {};

    for (final item in items) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }

    // Sort items within each category
    for (final categoryItems in grouped.values) {
      categoryItems.sort((a, b) => a.name.compareTo(b.name));
    }

    return grouped;
  }

  /// Calculate shopping list statistics
  static ShoppingListStats calculateStats(List<ShoppingListItem> items) {
    final totalItems = items.length;
    final checkedItems = items.where((item) => item.status == ShoppingListStatus.have).length;
    final categories = items.map((item) => item.category).toSet().length;
    final totalCost = items.fold<double>(0.0, (sum, item) => sum + item.totalCost);
    final estimatedCost = items
        .where((item) => item.status == ShoppingListStatus.needToBuy)
        .fold<double>(0.0, (sum, item) => sum + item.totalCost);
    final itemsWithPrices = items.where((item) => item.selectedPrice != null).length;
    
    return ShoppingListStats(
      totalItems: totalItems,
      checkedItems: checkedItems,
      uncheckedItems: totalItems - checkedItems,
      categories: categories,
      completionPercentage: totalItems > 0 ? (checkedItems / totalItems * 100) : 0,
      totalCost: totalCost,
      estimatedCost: estimatedCost,
      itemsWithPrices: itemsWithPrices,
    );
  }

  /// Get price comparison across supermarkets
  static Map<Supermarket, double> calculateSupermarketTotals(List<ShoppingListItem> items) {
    final Map<Supermarket, double> totals = {};
    
    for (final supermarket in Supermarket.values) {
      double total = 0.0;
      bool hasAllItems = true;
      
      for (final item in items) {
        if (item.status == ShoppingListStatus.have) continue;
        
        // Find price for this supermarket
        final supermarketPrice = item.availablePrices
            .where((price) => price.supermarket == supermarket)
            .isEmpty ? null : item.availablePrices
            .where((price) => price.supermarket == supermarket)
            .first;
            
        if (supermarketPrice != null) {
          final packsNeeded = (item.quantity / supermarketPrice.packageSize).ceil();
          total += supermarketPrice.price * packsNeeded;
        } else {
          hasAllItems = false;
          break;
        }
      }
      
      if (hasAllItems) {
        totals[supermarket] = total;
      }
    }
    
    return totals;
  }

  /// Get items with special offers
  static List<ShoppingListItem> getItemsWithSpecials(List<ShoppingListItem> items) {
    return items.where((item) => item.hasSpecialOffer).toList();
  }
}

class ShoppingListStats {
  final int totalItems;
  final int checkedItems;
  final int uncheckedItems;
  final int categories;
  final double completionPercentage;
  final double totalCost;
  final double estimatedCost;
  final int itemsWithPrices;

  const ShoppingListStats({
    required this.totalItems,
    required this.checkedItems,
    required this.uncheckedItems,
    required this.categories,
    required this.completionPercentage,
    required this.totalCost,
    required this.estimatedCost,
    required this.itemsWithPrices,
  });
}