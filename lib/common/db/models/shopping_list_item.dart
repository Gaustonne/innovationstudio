import 'dart:convert';
import 'package:uuid/uuid.dart';

enum ShoppingItemStatus { buy, have }

class PriceOption {
  final String store;
  final double price;
  final String unitInfo; // e.g., "200g" or "each"
  final String? special; // e.g., "Save $0.70"

  PriceOption({
    required this.store,
    required this.price,
    required this.unitInfo,
    this.special,
  });

  Map<String, dynamic> toMap() {
    return {
      'store': store,
      'price': price,
      'unitInfo': unitInfo,
      'special': special,
    };
  }

  factory PriceOption.fromMap(Map<String, dynamic> map) {
    return PriceOption(
      store: map['store'],
      price: map['price'],
      unitInfo: map['unitInfo'],
      special: map['special'],
    );
  }
}

class ShoppingListItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final ShoppingItemStatus status;
  final String category;
  final String? fromRecipe;
  final List<PriceOption> priceOptions;
  final String? selectedStore;

  ShoppingListItem({
    String? id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.status = ShoppingItemStatus.buy,
    this.category = 'Uncategorized',
    this.fromRecipe,
    this.priceOptions = const [],
    this.selectedStore,
  }) : id = id ?? const Uuid().v4();

  ShoppingListItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    ShoppingItemStatus? status,
    String? category,
    String? fromRecipe,
    List<PriceOption>? priceOptions,
    String? selectedStore,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      category: category ?? this.category,
      fromRecipe: fromRecipe ?? this.fromRecipe,
      priceOptions: priceOptions ?? this.priceOptions,
      selectedStore: selectedStore ?? this.selectedStore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'status': status.toString(),
      'category': category,
      'fromRecipe': fromRecipe,
      'priceOptions': jsonEncode(priceOptions.map((e) => e.toMap()).toList()),
      'selectedStore': selectedStore,
    };
  }

  factory ShoppingListItem.fromMap(Map<String, dynamic> map) {
    return ShoppingListItem(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
      unit: map['unit'],
      status: ShoppingItemStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => ShoppingItemStatus.buy,
      ),
      category: map['category'] ?? 'Uncategorized',
      fromRecipe: map['fromRecipe'],
      priceOptions: (jsonDecode(map['priceOptions'] ?? '[]') as List)
          .map((e) => PriceOption.fromMap(e))
          .toList(),
      selectedStore: map['selectedStore'],
    );
  }
}
