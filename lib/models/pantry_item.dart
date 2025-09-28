import 'ingredient.dart';

class PantryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final String category;

  const PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.category = 'Other',
  });

  PantryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    String? category,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      category: category ?? this.category,
    );
  }

  /// Check if this pantry item can satisfy the given ingredient requirement
  bool canSatisfy(Ingredient ingredient) {
    return name.toLowerCase() == ingredient.name.toLowerCase() &&
           unit.toLowerCase() == ingredient.unit.toLowerCase() &&
           quantity >= ingredient.quantity;
  }

  /// Get the remaining quantity after using the specified amount
  PantryItem useQuantity(double amount) {
    final newQuantity = (quantity - amount).clamp(0.0, double.infinity);
    return copyWith(quantity: newQuantity);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PantryItem &&
        other.name == name &&
        other.unit == unit;
  }

  @override
  int get hashCode => name.hashCode ^ unit.hashCode;

  @override
  String toString() {
    return 'PantryItem(name: $name, quantity: $quantity, unit: $unit)';
  }
}