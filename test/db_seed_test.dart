import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/common/db/collections/inventory_store.dart';
import 'package:inventory/common/db/collections/wasted_store.dart';
import 'package:inventory/common/db/models/ingredient.dart';
import 'test_helpers/db_test_helper.dart';

void main() {
  group('DB seed and clear tests', () {
    setUpAll(() async {
      await initTestDatabase();
    });

    tearDownAll(() async {
      await closeAndDeleteAppDatabase();
    });

    test('clear DB', () async {
      final inv = InventoryStore();
      final wasted = WastedStore();

      // clear any existing
      final existing = await inv.getAll();
      for (final e in existing) {
        await inv.delete(e.id);
      }
      final existingW = await wasted.getAll();
      for (final w in existingW) {
        await wasted.delete(w.id);
      }

      // verify empty
      final afterClear = await inv.getAll();
      final afterClearW = await wasted.getAll();
      expect(afterClear, isEmpty);
      expect(afterClearW, isEmpty);
    });

    test('seed DB with sample data and move item to wasted', () async {
      final inv = InventoryStore();
      final wasted = WastedStore();

      // insert sample inventory items
      final now = DateTime.now();
      final items = [
        Ingredient(
          name: 'Tomato',
          quantity: 5,
          weightKg: 1.2,
          expiry: now.add(Duration(days: 2)),
        ),
        Ingredient(
          name: 'Lettuce',
          quantity: 2,
          weightKg: 0.5,
          expiry: now.add(Duration(days: 5)),
        ),
        Ingredient(
          name: 'Milk',
          quantity: 1,
          weightKg: 1.0,
          expiry: now.add(Duration(days: 7)),
        ),
      ];

      for (final it in items) {
        await inv.insert(it);
      }

      final afterInsert = await inv.getAll();
      expect(afterInsert.length, equals(items.length));

      // move one to wasted
      final toWaste = afterInsert.first;
      await inv.delete(toWaste.id);
      await wasted.insert(toWaste, movedAt: DateTime.now());

      final afterMoveInv = await inv.getAll();
      final afterMoveW = await wasted.getAll();
      expect(afterMoveInv.length, equals(items.length - 1));
      expect(afterMoveW.length, equals(1));
    });
  });
}
