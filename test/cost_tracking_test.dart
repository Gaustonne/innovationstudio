import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/common/db/collections/inventory_store.dart';
import 'package:inventory/common/db/collections/wasted_store.dart';
import 'package:inventory/common/db/models/ingredient.dart';
import 'test_helpers/db_test_helper.dart';

void main() {
  group('Cost tracking tests', () {
    setUpAll(() async {
      await initTestDatabase();
    });

    tearDownAll(() async {
      await closeAndDeleteAppDatabase();
    });

    test('ingredient with cost can be moved to wasted and cost is preserved', () async {
      final inv = InventoryStore();
      final wasted = WastedStore();

      // Clear any existing data
      final existing = await inv.getAll();
      for (final e in existing) {
        await inv.delete(e.id);
      }
      final existingW = await wasted.getAll();
      for (final w in existingW) {
        await wasted.delete(w.id);
      }

      // Create an ingredient with cost
      final ingredient = Ingredient(
        name: 'Premium Milk',
        quantity: 1,
        weightKg: 1.0,
        expiry: DateTime.now().add(Duration(days: 7)),
        costAud: 4.50, // This is the key field to test
      );

      // Add to inventory
      await inv.insert(ingredient);

      // Verify it was inserted with cost
      final inventoryItems = await inv.getAll();
      expect(inventoryItems.length, 1);
      expect(inventoryItems.first.costAud, 4.50);

      // Move to wasted
      await wasted.insert(ingredient, movedAt: DateTime.now());

      // Remove from inventory
      await inv.delete(ingredient.id);

      // Verify it's in wasted with cost preserved
      final wastedItems = await wasted.getAll();
      expect(wastedItems.length, 1);
      expect(wastedItems.first.name, 'Premium Milk');
      expect(wastedItems.first.costAud, 4.50); // Cost should be preserved
      
      // Verify inventory is empty
      final remainingInventory = await inv.getAll();
      expect(remainingInventory.length, 0);
    });

    test('ingredient without cost can be moved to wasted', () async {
      final inv = InventoryStore();
      final wasted = WastedStore();

      // Clear any existing data
      final existing = await inv.getAll();
      for (final e in existing) {
        await inv.delete(e.id);
      }
      final existingW = await wasted.getAll();
      for (final w in existingW) {
        await wasted.delete(w.id);
      }

      // Create an ingredient without cost
      final ingredient = Ingredient(
        name: 'Basic Bread',
        quantity: 1,
        weightKg: 0.5,
        expiry: DateTime.now().add(Duration(days: 3)),
        // costAud is null
      );

      // Add to inventory
      await inv.insert(ingredient);

      // Move to wasted
      await wasted.insert(ingredient, movedAt: DateTime.now());

      // Remove from inventory
      await inv.delete(ingredient.id);

      // Verify it's in wasted with null cost
      final wastedItems = await wasted.getAll();
      expect(wastedItems.length, 1);
      expect(wastedItems.first.name, 'Basic Bread');
      expect(wastedItems.first.costAud, null); // Cost should be null
    });
  });
}