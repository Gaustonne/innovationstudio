import 'package:uuid/uuid.dart';

class Ingredient {
  final String id;
  final String name;
  final int quantity;
  final double weightKg;
  final DateTime expiry;
  final double? costAud;

  Ingredient({
    String? id,
    required this.name,
    required this.quantity,
    required this.weightKg,
    required this.expiry,
    this.costAud,
  }) : id = id ?? const Uuid().v4();

  Ingredient copyWith({
    String? id,
    String? name,
    int? quantity,
    double? weightKg,
    DateTime? expiry,
    double? costAud,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      weightKg: weightKg ?? this.weightKg,
      expiry: expiry ?? this.expiry,
      costAud: costAud ?? this.costAud,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'weightKg': weightKg,
    'expiry': expiry.toIso8601String(),
    'costAud': costAud,
  };

  factory Ingredient.fromMap(Map<String, dynamic> m) {
    final rawExpiry = m['expiry'];
    final DateTime expiry;
    if (rawExpiry is String) {
      expiry = DateTime.parse(rawExpiry);
    } else if (rawExpiry is int) {
      expiry = DateTime.fromMillisecondsSinceEpoch(rawExpiry);
    } else {
      expiry = DateTime.now();
    }

    // costAud may be null or a number
    double? cost;
    final rawCost = m['costAud'];
    if (rawCost == null) {
      cost = null;
    } else if (rawCost is num) {
      cost = rawCost.toDouble();
    } else if (rawCost is String) {
      cost = double.tryParse(rawCost);
    } else {
      cost = null;
    }

    return Ingredient(
      id: m['id'] as String,
      name: m['name'] as String,
      quantity: (m['quantity'] as num).toInt(),
      weightKg: (m['weightKg'] as num).toDouble(),
      expiry: expiry,
      costAud: cost,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ingredient && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
