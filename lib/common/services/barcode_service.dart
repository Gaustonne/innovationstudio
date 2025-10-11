import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductInfo {
  final String? productName;
  final String? brand;
  final String? quantity;
  final String? imageUrl;
  final String? categories;
  final bool isFound;

  const ProductInfo({
    this.productName,
    this.brand,
    this.quantity,
    this.imageUrl,
    this.categories,
    required this.isFound,
  });

  factory ProductInfo.notFound() {
    return const ProductInfo(isFound: false);
  }

  factory ProductInfo.fromOpenFoodFacts(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) {
      return ProductInfo.notFound();
    }

    // Extract size/quantity information from multiple sources
    String? extractedQuantity = _extractQuantityFromProduct(product);

    return ProductInfo(
      productName: product['product_name'] as String?,
      brand: product['brands'] as String?,
      quantity: extractedQuantity,
      imageUrl: product['image_url'] as String?,
      categories: product['categories'] as String?,
      isFound: true,
    );
  }

  static String? _extractQuantityFromProduct(Map<String, dynamic> product) {
    // Try multiple fields for quantity information
    final quantityFields = [
      'quantity',
      'serving_size',
      'net_weight',
      'product_quantity',
    ];

    for (final field in quantityFields) {
      final value = product[field] as String?;
      if (value?.isNotEmpty == true) {
        return value;
      }
    }

    // Extract from product name if it contains size info
    final name = product['product_name']?.toString() ?? '';
    final sizeRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l|oz|lb|pack|ct)\b', caseSensitive: false);
    final match = sizeRegex.firstMatch(name);

    if (match != null) {
      return '${match.group(1)}${match.group(2)}';
    }

    return null;
  }

  String get displayName {
    if (productName?.isNotEmpty == true) {
      return brand?.isNotEmpty == true ? '$brand $productName' : productName!;
    }
    return brand ?? 'Unknown Product';
  }

  String? get displayQuantity {
    if (quantity?.isNotEmpty == true) {
      return quantity;
    }
    return null;
  }
}

class BarcodeService {
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Lookup product information from a barcode using multiple sources
  Future<ProductInfo> lookupProduct(String barcode) async {
    // Clean and validate barcode
    String cleanBarcode = barcode.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    
    print('Original barcode: $barcode');
    print('Cleaned barcode: $cleanBarcode');
    
    // Try different barcode formats for Australian products
    List<String> barcodeVariations = [
      cleanBarcode,                                    // As scanned
      cleanBarcode.padLeft(13, '0'),                  // Pad to 13 digits
      cleanBarcode.padLeft(12, '0'),                  // Pad to 12 digits (UPC)
    ];
    
    // Add Australian prefix variations if not already present
    if (!cleanBarcode.startsWith('93')) {
      if (cleanBarcode.length >= 2) {
        barcodeVariations.add('93${cleanBarcode.substring(2)}');
      }
      barcodeVariations.add('93$cleanBarcode');
    }
    
    // Remove duplicates and invalid lengths
    barcodeVariations = barcodeVariations
        .toSet()
        .where((code) => code.length >= 8 && code.length <= 14)
        .toList();
    
    // Try Open Food Facts with each variation
    for (String testBarcode in barcodeVariations) {
      print('Trying barcode variation: $testBarcode');
      
      try {
        final result = await _lookupOpenFoodFacts(testBarcode);
        if (result.isFound) {
          print('Found product with barcode: $testBarcode');
          return result;
        }
      } catch (e) {
        print('OpenFoodFacts lookup failed for $testBarcode: $e');
      }
    }

    print('Product not found in any variation');
    return ProductInfo.notFound();
  }

  Future<ProductInfo> _lookupOpenFoodFacts(String barcode) async {
    final url = Uri.parse('$_openFoodFactsBaseUrl/$barcode.json');
    
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'KitchenInventoryApp/1.0 (Australian Product Lookup)',
      },
    ).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as int?;
      
      if (status == 1) {
        return ProductInfo.fromOpenFoodFacts(json);
      }
    }
    
    return ProductInfo.notFound();
  }

  /// Validate barcode format (basic check for common formats)
  bool isValidBarcode(String barcode) {
    if (barcode.isEmpty) return false;
    
    // Remove any non-digit characters
    final digits = barcode.replaceAll(RegExp(r'[^\d]'), '');
    
    print('Validating barcode: $barcode -> $digits (length: ${digits.length})');
    
    // Common barcode lengths: Code-128, EAN-8 (8), UPC-A (12), EAN-13 (13), etc.
    final validLengths = [8, 9, 10, 11, 12, 13, 14];
    
    final isValid = validLengths.contains(digits.length);
    print('Barcode validation result: $isValid');
    
    return isValid;
  }

  /// Format barcode for display
  String formatBarcode(String barcode) {
    final digits = barcode.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add common formatting based on length
    if (digits.length == 13) {
      // EAN-13 format: 1 234567 890123
      return '${digits[0]} ${digits.substring(1, 7)} ${digits.substring(7)}';
    } else if (digits.length == 12) {
      // UPC-A format: 123456 789012
      return '${digits.substring(0, 6)} ${digits.substring(6)}';
    }
    
    return digits;
  }
}