enum Supermarket { woolworths, coles, iga, aldi }

class ProductPrice {
  final String productId;
  final String productName;
  final String brand;
  final double price;
  final String unit;
  final double packageSize;
  final Supermarket supermarket;
  final bool onSpecial;
  final double? originalPrice;
  final String? specialOffer;

  const ProductPrice({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.price,
    required this.unit,
    required this.packageSize,
    required this.supermarket,
    this.onSpecial = false,
    this.originalPrice,
    this.specialOffer,
  });

  double get pricePerUnit => price / packageSize;
  double get savings => originalPrice != null ? (originalPrice! - price) : 0.0;

  String get supermarketName {
    switch (supermarket) {
      case Supermarket.woolworths:
        return 'Woolworths';
      case Supermarket.coles:
        return 'Coles';
      case Supermarket.iga:
        return 'IGA';
      case Supermarket.aldi:
        return 'ALDI';
    }
  }

  @override
  String toString() {
    return 'ProductPrice(name: $productName, price: \$${price.toStringAsFixed(2)}, supermarket: $supermarketName)';
  }
}

class SupermarketApiService {
  // Mock data for demonstration - in production, this would come from real APIs
  // API endpoints: Woolworths: https://www.woolworths.com.au/apis
  // Coles: https://shop.coles.com.au/api
  static final Map<String, List<ProductPrice>> _mockPrices = {
    'spaghetti': [
      ProductPrice(
        productId: 'ww_spaghetti_500g',
        productName: 'Spaghetti 500g',
        brand: 'San Remo',
        price: 2.50,
        unit: 'g',
        packageSize: 500,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_spaghetti_500g',
        productName: 'Spaghetti 500g',
        brand: 'Coles',
        price: 2.30,
        unit: 'g',
        packageSize: 500,
        supermarket: Supermarket.coles,
        onSpecial: true,
        originalPrice: 2.80,
        specialOffer: '50c off',
      ),
      ProductPrice(
        productId: 'iga_spaghetti_500g',
        productName: 'Spaghetti 500g',
        brand: 'La Famiglia',
        price: 2.80,
        unit: 'g',
        packageSize: 500,
        supermarket: Supermarket.iga,
      ),
    ],
    'eggs': [
      ProductPrice(
        productId: 'ww_eggs_12pack',
        productName: 'Free Range Eggs 12 Pack',
        brand: 'Woolworths',
        price: 6.50,
        unit: 'pieces',
        packageSize: 12,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_eggs_12pack',
        productName: 'Free Range Eggs 12 Pack',
        brand: 'Coles',
        price: 6.20,
        unit: 'pieces',
        packageSize: 12,
        supermarket: Supermarket.coles,
      ),
      ProductPrice(
        productId: 'aldi_eggs_12pack',
        productName: 'Free Range Eggs 12 Pack',
        brand: 'Farmdale',
        price: 4.99,
        unit: 'pieces',
        packageSize: 12,
        supermarket: Supermarket.aldi,
      ),
    ],
    'pancetta': [
      ProductPrice(
        productId: 'ww_pancetta_100g',
        productName: 'Pancetta 100g',
        brand: 'Don',
        price: 4.50,
        unit: 'g',
        packageSize: 100,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_pancetta_100g',
        productName: 'Pancetta 100g',
        brand: 'Primo',
        price: 4.20,
        unit: 'g',
        packageSize: 100,
        supermarket: Supermarket.coles,
      ),
    ],
    'parmesan cheese': [
      ProductPrice(
        productId: 'ww_parmesan_200g',
        productName: 'Parmesan Cheese 200g',
        brand: 'Perfect Italiano',
        price: 8.50,
        unit: 'g',
        packageSize: 200,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_parmesan_200g',
        productName: 'Parmesan Cheese 200g',
        brand: 'Coles',
        price: 7.80,
        unit: 'g',
        packageSize: 200,
        supermarket: Supermarket.coles,
        onSpecial: true,
        originalPrice: 8.50,
        specialOffer: 'Save \$0.70',
      ),
    ],
    'romaine lettuce': [
      ProductPrice(
        productId: 'ww_lettuce_head',
        productName: 'Cos Lettuce',
        brand: 'Fresh',
        price: 3.50,
        unit: 'heads',
        packageSize: 1,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_lettuce_head',
        productName: 'Cos Lettuce',
        brand: 'Fresh',
        price: 3.80,
        unit: 'heads',
        packageSize: 1,
        supermarket: Supermarket.coles,
      ),
    ],
    'chicken breast': [
      ProductPrice(
        productId: 'ww_chicken_500g',
        productName: 'Chicken Breast 500g',
        brand: 'Lilydale',
        price: 12.50,
        unit: 'g',
        packageSize: 500,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_chicken_500g',
        productName: 'Chicken Breast 500g',
        brand: 'Coles RSPCA',
        price: 11.90,
        unit: 'g',
        packageSize: 500,
        supermarket: Supermarket.coles,
      ),
      ProductPrice(
        productId: 'aldi_chicken_500g',
        productName: 'Chicken Breast 500g',
        brand: 'Never Any',
        price: 10.99,
        unit: 'g',
        packageSize: 500,
        supermarket: Supermarket.aldi,
      ),
    ],
    'bell peppers': [
      ProductPrice(
        productId: 'ww_capsicum_each',
        productName: 'Red Capsicum',
        brand: 'Fresh',
        price: 2.50,
        unit: 'pieces',
        packageSize: 1,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_capsicum_each',
        productName: 'Red Capsicum',
        brand: 'Fresh',
        price: 2.80,
        unit: 'pieces',
        packageSize: 1,
        supermarket: Supermarket.coles,
      ),
    ],
    'broccoli': [
      ProductPrice(
        productId: 'ww_broccoli_bunch',
        productName: 'Broccoli 400g',
        brand: 'Fresh',
        price: 4.50,
        unit: 'g',
        packageSize: 400,
        supermarket: Supermarket.woolworths,
      ),
      ProductPrice(
        productId: 'coles_broccoli_bunch',
        productName: 'Broccoli 400g',
        brand: 'Fresh',
        price: 4.20,
        unit: 'g',
        packageSize: 400,
        supermarket: Supermarket.coles,
      ),
    ],
  };

  /// Search for product prices across Australian supermarkets
  static Future<List<ProductPrice>> searchProductPrices(String productName) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // In production, this would make actual API calls to:
    // - Woolworths: https://www.woolworths.com.au/apis/ui/product/search
    // - Coles: https://shop.coles.com.au/api/products/search
    // - IGA: Various state-based APIs
    
    final normalizedName = productName.toLowerCase().trim();
    
    // Try exact match first
    if (_mockPrices.containsKey(normalizedName)) {
      return _mockPrices[normalizedName]!;
    }
    
    // Try partial matches
    for (final entry in _mockPrices.entries) {
      if (entry.key.contains(normalizedName) || normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Return empty list if no matches found
    return [];
  }

  /// Get the best price for a specific product
  static Future<ProductPrice?> getBestPrice(String productName) async {
    final prices = await searchProductPrices(productName);
    if (prices.isEmpty) return null;
    
    // Sort by price per unit (lowest first)
    prices.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    return prices.first;
  }

  /// Get prices grouped by supermarket
  static Future<Map<Supermarket, List<ProductPrice>>> getPricesBySupermarket(
    List<String> productNames,
  ) async {
    final Map<Supermarket, List<ProductPrice>> result = {};
    
    for (final productName in productNames) {
      final prices = await searchProductPrices(productName);
      for (final price in prices) {
        if (!result.containsKey(price.supermarket)) {
          result[price.supermarket] = [];
        }
        result[price.supermarket]!.add(price);
      }
    }
    
    return result;
  }

  /// Calculate total cost for a shopping list at each supermarket
  static Future<Map<Supermarket, double>> calculateTotalCosts(
    Map<String, int> shoppingList, // product name -> quantity needed
  ) async {
    final Map<Supermarket, double> totals = {};
    
    for (final supermarket in Supermarket.values) {
      totals[supermarket] = 0.0;
    }
    
    for (final entry in shoppingList.entries) {
      final productName = entry.key;
      final quantityNeeded = entry.value;
      final prices = await searchProductPrices(productName);
      
      for (final price in prices) {
        final packsNeeded = (quantityNeeded / price.packageSize).ceil();
        final cost = price.price * packsNeeded;
        totals[price.supermarket] = (totals[price.supermarket] ?? 0.0) + cost;
      }
    }
    
    // Remove supermarkets with no available products
    totals.removeWhere((key, value) => value == 0.0);
    
    return totals;
  }

  /// Get weekly specials across supermarkets
  static Future<List<ProductPrice>> getWeeklySpecials() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final allPrices = _mockPrices.values.expand((prices) => prices).toList();
    return allPrices.where((price) => price.onSpecial).toList();
  }
}