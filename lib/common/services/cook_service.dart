import 'dart:math';
import '../db/collections/inventory_store.dart';
import '../db/models/ingredient.dart';
import 'app_events.dart';

/// A single inventory change (used for Undo).
class CookChange {
  final String ingredientId;
  final String name;
  final int delta; // negative when we deduct, positive when we undo

  const CookChange({
    required this.ingredientId,
    required this.name,
    required this.delta,
  });
}

/// Result of applying a "cook" action.
class CookResult {
  final List<CookChange> applied;     // what we actually deducted
  final Map<String, int> shortages;   // name -> missing amount

  const CookResult({
    required this.applied,
    required this.shortages,
  });
}

class CookService {
  final InventoryStore _inv = InventoryStore();

  /// Deduct quantities by **ingredient name** (case-insensitive).
  /// Example input: { 'Tomato': 2, 'Eggs': 4 }
  Future<CookResult> apply(Map<String, int> useByName) async {
    if (useByName.isEmpty) {
      return const CookResult(applied: [], shortages: {});
    }

    final items = await _inv.getAll();
    final byLower = { for (final it in items) it.name.toLowerCase(): it };

    final applied = <CookChange>[];
    final shortages = <String, int>{};

    for (final entry in useByName.entries) {
      final name = entry.key.trim();
      final want = max(0, entry.value);
      if (want == 0) continue;

      final match = byLower[name.toLowerCase()];
      if (match == null) {
        shortages[name] = want; // not found in pantry
        continue;
      }

      final have = match.quantity;
      final take = min(have, want); // don’t go below zero
      final newQty = have - take;

      if (newQty <= 0) {
        await _inv.delete(match.id);
      } else {
        await _inv.update(match.copyWith(quantity: newQty));
      }

      if (take > 0) {
        applied.add(CookChange(
          ingredientId: match.id,
          name: match.name,
          delta: -take,
        ));
      }
      if (want > have) {
        shortages[name] = want - have;
      }
    }

    // Notify other screens (inventory list, drawer counts, etc.)
    AppEvents.instance.requestReloadAll();

    return CookResult(applied: applied, shortages: shortages);
  }

  /// Undo previously applied deductions.
  Future<void> undo(List<CookChange> changes) async {
    if (changes.isEmpty) return;

    final items = await _inv.getAll();
    final byId = { for (final it in items) it.id: it };

    for (final c in changes) {
      final addBack = c.delta.abs();

      final cur = byId[c.ingredientId];
      if (cur == null) {
        // If the row was deleted, recreate a minimal one so Undo always works.
        final recreated = Ingredient(
          id: c.ingredientId,
          name: c.name,
          quantity: addBack,
          weightKg: 0,
          expiry: DateTime.now().add(const Duration(days: 7)),
        );
        await _inv.insert(recreated);
      } else {
        await _inv.update(cur.copyWith(quantity: cur.quantity + addBack));
      }
    }

    AppEvents.instance.requestReloadAll();
  }
}