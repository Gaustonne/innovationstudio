import 'package:flutter/material.dart';
import '../../../common/db/models/ingredient.dart';
import '../../../common/utils/date_utils.dart';

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
                          if (item.expiry.millisecondsSinceEpoch == 0)
                            const Text(
                              'Expiry: Not set',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else ...[
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
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
