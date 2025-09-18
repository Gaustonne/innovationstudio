import 'package:uuid/uuid.dart';

class Ingredient {
  final String id;
  final String name;
  final int quantity;
  final double weightKg;
  final DateTime expiry;

  Ingredient({
    String? id,
    required this.name,
    required this.quantity,
    required this.weightKg,
    required this.expiry,
  }) : id = id ?? const Uuid().v4();

  Ingredient copyWith({
    String? id,
    String? name,
    int? quantity,
    double? weightKg,
    DateTime? expiry,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      weightKg: weightKg ?? this.weightKg,
      expiry: expiry ?? this.expiry,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'weightKg': weightKg,
    'expiry': expiry.toIso8601String(),
  };

  factory Ingredient.fromMap(Map<String, Object?> m) => Ingredient(
    id: m['id'] as String?,
    name: m['name'] as String,
    quantity: (m['quantity'] as num).toInt(),
    weightKg: (m['weightKg'] as num).toDouble(),
    expiry: DateTime.parse(m['expiry'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ingredient && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
