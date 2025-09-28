import 'package:flutter/material.dart';
import '../../../common/db/models/ingredient.dart';
import 'item_card.dart';

class WastedItemsPage extends StatelessWidget {
  final List<Ingredient> items;

  const WastedItemsPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        key: const PageStorageKey('wastedList'),
        itemCount: items.length,
        itemBuilder: (context, index) => ItemCard(item: items[index]),
      ),
    );
  }
}
