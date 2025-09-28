class Ingredient {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final double packSize;
  final String category;

  const Ingredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.packSize = 1.0,
    this.category = 'Other',
  });

  Ingredient copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    double? packSize,
    String? category,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      packSize: packSize ?? this.packSize,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ingredient &&
        other.name == name &&
        other.unit == unit;
  }

  @override
  int get hashCode => name.hashCode ^ unit.hashCode;

  @override
  String toString() {
    return 'Ingredient(name: $name, quantity: $quantity, unit: $unit, packSize: $packSize)';
  }
}