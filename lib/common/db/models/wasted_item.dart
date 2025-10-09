import 'package:uuid/uuid.dart';
import '../models/ingredient.dart';

class WastedItem {
  final String id;
  final String name;
  final double? quantity;
  final String? unit;
  final double? weightKg;
  final DateTime movedAt;
  final String? reason;
  final double? estValue;
  final String? origExpiry; // store expiry for undo

  WastedItem({
    String? id,
    required this.name,
    this.quantity,
    this.unit,
    this.weightKg,
    DateTime? movedAt,
    this.reason,
    this.estValue,
    this.origExpiry,
  })  : id = id ?? const Uuid().v4(),
        movedAt = movedAt ?? DateTime.now();

  factory WastedItem.fromMap(Map<String, dynamic> m) => WastedItem(
        id: m['id'] as String,
        name: m['name'] as String,
        quantity: (m['quantity'] as num?)?.toDouble(),
        unit: m['unit'] as String?,
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        movedAt: DateTime.fromMillisecondsSinceEpoch(m['movedAt'] as int),
        reason: m['reason'] as String?,
        estValue: (m['estValue'] as num?)?.toDouble(),
        origExpiry: m['origExpiry'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'weightKg': weightKg,
        'movedAt': movedAt.millisecondsSinceEpoch,
        'reason': reason,
        'estValue': estValue,
        'origExpiry': origExpiry,
      };

  Ingredient toIngredient() {
    final int safeQty = ((quantity ?? 1).toDouble()).floor();
    final double safeWeight = (weightKg ?? 0).toDouble();
    final String safeUnit = unit ?? '';

    final expiryDate = origExpiry != null
        ? DateTime.tryParse(origExpiry!) ?? DateTime.now()
        : DateTime.now();

    return Ingredient.fromMap({
      'id': const Uuid().v4(),
      'name': name,
      'quantity': safeQty,
      'unit': safeUnit,
      'weightKg': safeWeight,
      'expiry': expiryDate.toIso8601String(),
    });
  }
}