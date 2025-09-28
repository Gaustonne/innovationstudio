import 'ingredient.dart';
import '../services/supermarket_api_service.dart';

enum ShoppingListStatus {
  needToBuy,
  have,
}

class ShoppingListItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final double packSize;
  final int packsNeeded;
  final double totalQuantity;
  final String category;
  final ShoppingListStatus status;
  final List<String> sourceRecipes;
  final List<ProductPrice> availablePrices;
  final ProductPrice? selectedPrice;

  const ShoppingListItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.packSize,
    required this.packsNeeded,
    required this.totalQuantity,
    this.category = 'Other',
    this.status = ShoppingListStatus.needToBuy,
    this.sourceRecipes = const [],
    this.availablePrices = const [],
    this.selectedPrice,
  });

  factory ShoppingListItem.fromIngredient(
    Ingredient ingredient, {
    List<String> sourceRecipes = const [],
    List<ProductPrice> availablePrices = const [],
  }) {
    final packsNeeded = (ingredient.quantity / ingredient.packSize).ceil();
    final totalQuantity = packsNeeded * ingredient.packSize;

    // Select the best price (lowest price per unit) if available
    ProductPrice? selectedPrice;
    if (availablePrices.isNotEmpty) {
      final sortedPrices = List<ProductPrice>.from(availablePrices);
      sortedPrices.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
      selectedPrice = sortedPrices.first;
    }

    return ShoppingListItem(
      id: ingredient.id,
      name: ingredient.name,
      quantity: ingredient.quantity,
      unit: ingredient.unit,
      packSize: ingredient.packSize,
      packsNeeded: packsNeeded,
      totalQuantity: totalQuantity,
      category: ingredient.category,
      sourceRecipes: sourceRecipes,
      availablePrices: availablePrices,
      selectedPrice: selectedPrice,
    );
  }

  ShoppingListItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    double? packSize,
    int? packsNeeded,
    double? totalQuantity,
    String? category,
    ShoppingListStatus? status,
    List<String>? sourceRecipes,
    List<ProductPrice>? availablePrices,
    ProductPrice? selectedPrice,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      packSize: packSize ?? this.packSize,
      packsNeeded: packsNeeded ?? this.packsNeeded,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      category: category ?? this.category,
      status: status ?? this.status,
      sourceRecipes: sourceRecipes ?? this.sourceRecipes,
      availablePrices: availablePrices ?? this.availablePrices,
      selectedPrice: selectedPrice ?? this.selectedPrice,
    );
  }

  /// Toggle the status between 'need to buy' and 'have'
  ShoppingListItem toggleStatus() {
    final newStatus = status == ShoppingListStatus.needToBuy
        ? ShoppingListStatus.have
        : ShoppingListStatus.needToBuy;
    return copyWith(status: newStatus);
  }

  /// Add quantity from another ingredient (for merging)
  ShoppingListItem addQuantity(double additionalQuantity, List<String> additionalRecipes) {
    final newQuantity = quantity + additionalQuantity;
    final newPacksNeeded = (newQuantity / packSize).ceil();
    final newTotalQuantity = newPacksNeeded * packSize;
    final combinedRecipes = [...sourceRecipes, ...additionalRecipes].toSet().toList();

    return copyWith(
      quantity: newQuantity,
      packsNeeded: newPacksNeeded,
      totalQuantity: newTotalQuantity,
      sourceRecipes: combinedRecipes,
    );
  }

  /// Calculate the total cost for this item
  double get totalCost {
    if (selectedPrice == null) return 0.0;
    return selectedPrice!.price * packsNeeded;
  }

  /// Get the price per unit for the selected price
  double get pricePerUnit {
    return selectedPrice?.pricePerUnit ?? 0.0;
  }

  /// Check if this item has a special offer
  bool get hasSpecialOffer {
    return selectedPrice?.onSpecial ?? false;
  }

  /// Get savings amount if on special
  double get savings {
    return selectedPrice?.savings ?? 0.0;
  }

  /// Get the cheapest available price
  ProductPrice? get cheapestPrice {
    if (availablePrices.isEmpty) return null;
    final sorted = List<ProductPrice>.from(availablePrices);
    sorted.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    return sorted.first;
  }

  /// Select a different price option
  ShoppingListItem selectPrice(ProductPrice price) {
    return copyWith(selectedPrice: price);
  }

  String get displayQuantity {
    if (packsNeeded == 1) {
      return '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} $unit';
    } else {
      return '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} $unit ($packsNeeded × ${packSize.toStringAsFixed(packSize.truncateToDouble() == packSize ? 0 : 1)} $unit)';
    }
  }

  String get displayPrice {
    if (selectedPrice == null) return 'Price not available';
    
    final priceText = '\$${selectedPrice!.price.toStringAsFixed(2)}';
    if (packsNeeded > 1) {
      return '$priceText each × $packsNeeded = \$${totalCost.toStringAsFixed(2)}';
    }
    return priceText;
  }

  String get displayPriceWithSpecial {
    if (selectedPrice == null) return 'Price not available';
    
    if (hasSpecialOffer) {
      return '\$${selectedPrice!.price.toStringAsFixed(2)} (Save \$${savings.toStringAsFixed(2)})';
    }
    return displayPrice;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingListItem &&
        other.name == name &&
        other.unit == unit;
  }

  @override
  int get hashCode => name.hashCode ^ unit.hashCode;

  @override
  String toString() {
    return 'ShoppingListItem(name: $name, quantity: $quantity, packs: $packsNeeded, status: $status)';
  }
}