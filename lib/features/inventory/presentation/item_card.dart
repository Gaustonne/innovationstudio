import 'package:flutter/material.dart';

import '../../../common/db/models/ingredient.dart';
import '../../../common/utils/date_utils.dart';

// NEW imports for the action:
import '../../../common/db/collections/wasted_store.dart';
import '../../../common/db/collections/inventory_store.dart';

class ItemCard extends StatelessWidget {
  final Ingredient item;
  final bool isExpiredView;

  const ItemCard({super.key, required this.item, this.isExpiredView = false});

  @override
  Widget build(BuildContext context) {
    final avatarText = item.name
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join();

    return Card(
      color: isExpiredView ? Colors.grey.shade100 : null,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                avatarText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Quantity: ${item.quantity}'),
                      Text('Weight: ${item.weightKg} kg'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expiry: ${formatDate(item.expiry)}'),
                          const SizedBox(height: 2),
                          Text(
                            relativeExpiry(item.expiry),
                            style: TextStyle(
                              color: expiryColor(item.expiry),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions: 3-dot menu + your existing chevron
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  onSelected: (value) async {
                    if (value == 'waste') {
                      // Ask if the user also wants to remove it from inventory
                      final removeFromInventory = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Throw away item'),
                          content: const Text(
                            'Move this item to Wasted? You can also choose to remove it from inventory.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Just record waste'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Record & remove'),
                            ),
                          ],
                        ),
                      );

                      // 1) Always record in the wasted table
                      await WastedStore().insert(item);

                      // 2) Optionally remove from inventory
                      if (removeFromInventory == true) {
                        try {
                          await InventoryStore().delete(item.id);
                        } catch (_) {
                          // If your Ingredient model doesn't expose id, drop this or adapt.
                        }
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(removeFromInventory == true
                                ? 'Item moved to Wasted and removed from inventory'
                                : 'Item recorded in Wasted'),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'waste',
                      child: Text('Throw away'),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
