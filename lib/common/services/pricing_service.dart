import 'dart:math';
import '../db/models/shopping_list_item.dart';

class PricingService {
  final _random = Random();
  final _stores = ['Coles', 'Woolworths', 'Aldi'];
  final _basePrices = {
    'soy sauce': 2.50,
    'parmesan cheese': 7.00,
    'chicken breast': 10.00,
    'pancetta': 4.00,
    'eggs': 5.00,
    'spaghetti': 2.00,
    'garlic': 1.00,
    'olive oil': 8.00,
    'tomato': 1.50,
    'lettuce': 2.00,
    'milk': 1.80,
    'cheese': 6.00,
  };

  Future<List<PriceOption>> getPriceOptions(String itemName) async {
    await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(800)));

    final basePrice = _basePrices[itemName.toLowerCase()] ?? (_random.nextDouble() * 10 + 1);
    final numOptions = _random.nextInt(2) + 2; // 2 or 3 options

    final options = <PriceOption>[];
    final usedStores = <String>{};

    for (int i = 0; i < numOptions; i++) {
      String store;
      do {
        store = _stores[_random.nextInt(_stores.length)];
      } while (usedStores.contains(store));
      usedStores.add(store);

      final priceVariance = (_random.nextDouble() * 0.4) - 0.2; // -20% to +20%
      final price = basePrice * (1 + priceVariance);
      final isSpecial = _random.nextDouble() > 0.7;
      final specialSave = isSpecial ? (price * (_random.nextDouble() * 0.1 + 0.1)) : 0.0;

      options.add(
        PriceOption(
          store: store,
          price: price,
          unitInfo: 'each',
          special: isSpecial ? 'Save \$${specialSave.toStringAsFixed(2)}' : null,
        ),
      );
    }

    options.sort((a, b) => a.price.compareTo(b.price));
    return options;
  }
}
