import 'package:flutter/material.dart';

import '../../../common/db/models/ingredient.dart';
import 'item_card.dart';
// <-- This is the new charts screen you'll add next.
import 'waste_charts_screen.dart';

class WastedItemsPage extends StatelessWidget {
  final List<Ingredient> items;

  const WastedItemsPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header: lightweight summary + Charts button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Text(
                'Wasted items: ${items.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Charts'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WasteChartsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Original list (unchanged behavior)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ListView.builder(
              key: const PageStorageKey('wastedList'),
              itemCount: items.length,
              itemBuilder: (context, index) => ItemCard(item: items[index]),
            ),
          ),
        ),
      ],
    );
  }
}
