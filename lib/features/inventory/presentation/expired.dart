import 'package:flutter/material.dart';
import '../../../common/db/models/ingredient.dart';
import 'item_card.dart';

class ExpiredItemsPage extends StatelessWidget {
  final List<Ingredient> items;
  final void Function(Ingredient) onAddDays;
  final void Function(Ingredient) onWaste;

  const ExpiredItemsPage({
    super.key,
    required this.items,
    required this.onAddDays,
    required this.onWaste,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        key: const PageStorageKey('expiredList'),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Dismissible(
            key: ValueKey(item.id),
            background: Container(
              color: Colors.green,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: const [
                  Icon(Icons.update, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Add 3 days', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Send to wasted', style: TextStyle(color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.delete_forever, color: Colors.white),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              // Capture messenger before any await to avoid using BuildContext across async gaps.
              final messenger = ScaffoldMessenger.of(context);
              if (direction == DismissDirection.startToEnd) {
                // Right swipe: add 3 days to expiry
                onAddDays(item);
                messenger.showSnackBar(
                  SnackBar(content: Text('Extended "${item.name}" by 3 days')),
                );
                // Don't dismiss visually if we updated expiry (it may still be expired)
                return false;
              } else {
                // Left swipe: send to wasted
                final confirmed =
                    await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Send to wasted?'),
                        content: Text('Move "${item.name}" to wasted items?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirmed) {
                  onWaste(item);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Moved "${item.name}" to wasted items'),
                    ),
                  );
                  return true;
                }
                return false;
              }
            },
            child: ItemCard(item: item, isExpiredView: true),
          );
        },
      ),
    );
  }
}
