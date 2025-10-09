import 'package:uuid/uuid.dart';

import 'wasted_item.dart';
import 'ingredient.dart';

extension WastedItemToIngredient on WastedItem {
  Ingredient toIngredient() {
    // Safe numeric fallbacks
    final int safeQty = ((quantity ?? 1).toDouble()).floor();
    final double safeWeight = (weightKg ?? 0).toDouble();
    final String safeUnit = unit ?? '';

    // Parse original expiry (stored as ISO string) if present
    DateTime expiryDt;
    if (origExpiry != null && origExpiry!.trim().isNotEmpty) {
      try {
        expiryDt = DateTime.parse(origExpiry!);
      } catch (_) {
        expiryDt = DateTime.now();
      }
    } else {
      expiryDt = DateTime.now();
    }

    // Build an Ingredient map that matches Ingredient.fromMap expectations
    return Ingredient.fromMap({
      'id': const Uuid().v4(),
      'name': name,
      'quantity': safeQty,                 // int
      'unit': safeUnit,                    // String (non-null)
      'weightKg': safeWeight,              // double
      'expiry': expiryDt.toIso8601String() // String ISO (also accepted by fromMap)
    });
  }
}