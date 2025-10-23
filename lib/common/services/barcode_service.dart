import 'dart:convert';
import 'package:http/http.dart' as http;

class BarcodeStructure {
  final String originalBarcode;
  final String cleanBarcode;
  final BarcodeType type;
  final String? gs1Prefix;
  final String? countryCode;
  final String? manufacturerCode;
  final String? productCode;
  final String? checkDigit;
  final bool isValidChecksum;

  const BarcodeStructure({
    required this.originalBarcode,
    required this.cleanBarcode,
    required this.type,
    this.gs1Prefix,
    this.countryCode,
    this.manufacturerCode,
    this.productCode,
    this.checkDigit,
    required this.isValidChecksum,
  });
}

enum BarcodeType {
  ean13,
  ean8,
  upcA,
  upcE,
  code128,
  qrCode,
  dataMatrix,
  unknown
}

class ExtendedBarcodeData {
  final DateTime? expiryDate;
  final DateTime? bestBeforeDate;
  final String? batchNumber;
  final String? lotNumber;
  final double? variableWeight;
  final String? serialNumber;
  final Map<String, String> additionalData;

  const ExtendedBarcodeData({
    this.expiryDate,
    this.bestBeforeDate,
    this.batchNumber,
    this.lotNumber,
    this.variableWeight,
    this.serialNumber,
    this.additionalData = const {},
  });

  factory ExtendedBarcodeData.fromGS1String(String gs1Data) {
    final Map<String, String> parsedData = {};
    DateTime? expiryDate;
    DateTime? bestBeforeDate;
    String? batchNumber;
    String? lotNumber;
    double? variableWeight;
    String? serialNumber;

    // Parse GS1 Application Identifiers (AIs)
    final RegExp aiPattern = RegExp(r'\((\d{2,4})\)([^(]+)');
    final matches = aiPattern.allMatches(gs1Data);

    for (final match in matches) {
      final ai = match.group(1)!;
      final value = match.group(2)!.trim();
      parsedData[ai] = value;

      switch (ai) {
        case '01': // GTIN (Global Trade Item Number)
          break;
        case '10': // Batch/Lot number
          batchNumber = value;
          break;
        case '11': // Production date (YYMMDD)
          // Parse production date if needed
          break;
        case '15': // Best before date (YYMMDD)
          bestBeforeDate = _parseGS1Date(value);
          break;
        case '17': // Expiry date (YYMMDD)
          expiryDate = _parseGS1Date(value);
          break;
        case '20': // Product variant
          break;
        case '21': // Serial number
          serialNumber = value;
          break;
        case '310': // Net weight in kg (variable measure)
        case '3100': case '3101': case '3102': case '3103': case '3104': case '3105':
          variableWeight = _parseVariableWeight(ai, value);
          break;
        case '320': // Net weight in pounds
          // Convert pounds to kg if needed
          break;
      }
    }

    return ExtendedBarcodeData(
      expiryDate: expiryDate,
      bestBeforeDate: bestBeforeDate,
      batchNumber: batchNumber,
      lotNumber: lotNumber,
      variableWeight: variableWeight,
      serialNumber: serialNumber,
      additionalData: parsedData,
    );
  }

  static DateTime? _parseGS1Date(String dateStr) {
    if (dateStr.length != 6) return null;
    
    try {
      final year = int.parse(dateStr.substring(0, 2));
      final month = int.parse(dateStr.substring(2, 4));
      final day = int.parse(dateStr.substring(4, 6));
      
      // Convert 2-digit year to 4-digit (assume 2000s for 00-30, 1900s for 31-99)
      final fullYear = year <= 30 ? 2000 + year : 1900 + year;
      
      return DateTime(fullYear, month, day);
    } catch (e) {
      return null;
    }
  }

  static double? _parseVariableWeight(String ai, String value) {
    try {
      final decimals = int.parse(ai.substring(ai.length - 1));
      final weight = int.parse(value);
      return weight / (1 * (10 ^ decimals)); // Apply decimal places
    } catch (e) {
      return null;
    }
  }
}

class ProductInfo {
  final String? productName;
  final String? brand;
  final String? quantity;
  final String? imageUrl;
  final String? categories;
  final bool isFound;
  final BarcodeStructure? barcodeStructure;
  final ExtendedBarcodeData? extendedData;

  const ProductInfo({
    this.productName,
    this.brand,
    this.quantity,
    this.imageUrl,
    this.categories,
    required this.isFound,
    this.barcodeStructure,
    this.extendedData,
  });

  factory ProductInfo.notFound({BarcodeStructure? barcodeStructure}) {
    return ProductInfo(
      isFound: false, 
      barcodeStructure: barcodeStructure,
    );
  }

  factory ProductInfo.fromOpenFoodFacts(Map<String, dynamic> json, {
    BarcodeStructure? barcodeStructure,
    ExtendedBarcodeData? extendedData,
  }) {
    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) {
      return ProductInfo.notFound(barcodeStructure: barcodeStructure);
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
      barcodeStructure: barcodeStructure,
      extendedData: extendedData,
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
    // Prefer variable weight from 2D barcode if available
    if (extendedData?.variableWeight != null) {
      return '${extendedData!.variableWeight!.toStringAsFixed(3)}kg';
    }
    
    if (quantity?.isNotEmpty == true) {
      return quantity;
    }
    return null;
  }

  String get countryOfRegistration {
    if (barcodeStructure?.countryCode != null) {
      return _getCountryFromGS1Prefix(barcodeStructure!.countryCode!);
    }
    return 'Unknown';
  }

  static String _getCountryFromGS1Prefix(String prefix) {
    // Common GS1 prefixes for major markets
    switch (prefix.substring(0, 2)) {
      case '93': return 'Australia';
      case '00': case '01': case '02': case '03': case '04': case '05':
      case '06': case '07': case '08': case '09': return 'USA & Canada';
      case '40': case '41': case '42': case '43': case '44': return 'Germany';
      case '45': case '49': return 'Japan';
      case '50': return 'United Kingdom';
      case '54': return 'Belgium & Luxembourg';
      case '57': return 'Denmark';
      case '64': return 'Finland';
      case '69': return 'China';
      case '70': return 'Norway';
      case '72': return 'Israel';
      case '73': return 'Sweden';
      case '76': return 'Switzerland';
      case '80': case '81': case '82': case '83': return 'Italy';
      case '84': return 'Spain';
      case '87': return 'Netherlands';
      case '90': case '91': return 'Austria';
      case '94': return 'New Zealand';
      default: return 'Unknown';
    }
  }
}

class BarcodeService {
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Enhanced barcode lookup with structure analysis and 2D data parsing
  Future<ProductInfo> lookupProduct(String barcode, {String? rawBarcodeData}) async {
    print('Processing barcode: $barcode');
    if (rawBarcodeData != null) {
      print('Raw barcode data: $rawBarcodeData');
    }

    // Parse extended data from 2D barcodes (like QR codes with GS1 data)
    ExtendedBarcodeData? extendedData;
    if (rawBarcodeData != null && rawBarcodeData.contains('(')) {
      extendedData = ExtendedBarcodeData.fromGS1String(rawBarcodeData);
      print('Parsed extended data: expiry=${extendedData.expiryDate}, batch=${extendedData.batchNumber}, weight=${extendedData.variableWeight}');
    }

    // Analyze barcode structure
    final barcodeStructure = _analyzeBarcodeStructure(barcode);
    print('Barcode structure: ${barcodeStructure.type}, Country: ${barcodeStructure.countryCode}, Valid checksum: ${barcodeStructure.isValidChecksum}');

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
        final result = await _lookupOpenFoodFacts(testBarcode, 
          barcodeStructure: barcodeStructure, 
          extendedData: extendedData
        );
        if (result.isFound) {
          print('Found product with barcode: $testBarcode');
          return result;
        }
      } catch (e) {
        print('OpenFoodFacts lookup failed for $testBarcode: $e');
      }
    }

    print('Product not found in any variation');
    return ProductInfo.notFound(barcodeStructure: barcodeStructure);
  }

  /// Analyze EAN-13/UPC barcode structure according to GS1 standards
  BarcodeStructure _analyzeBarcodeStructure(String barcode) {
    final cleanBarcode = barcode.replaceAll(RegExp(r'\D'), '');
    
    BarcodeType type = BarcodeType.unknown;
    String? gs1Prefix;
    String? countryCode;
    String? manufacturerCode;
    String? productCode;
    String? checkDigit;
    bool isValidChecksum = false;

    switch (cleanBarcode.length) {
      case 8:
        type = BarcodeType.ean8;
        countryCode = cleanBarcode.substring(0, 2);
        manufacturerCode = cleanBarcode.substring(2, 5);
        productCode = cleanBarcode.substring(5, 7);
        checkDigit = cleanBarcode.substring(7, 8);
        isValidChecksum = _validateEAN8Checksum(cleanBarcode);
        break;
        
      case 12:
        type = BarcodeType.upcA;
        manufacturerCode = cleanBarcode.substring(0, 6);
        productCode = cleanBarcode.substring(6, 11);
        checkDigit = cleanBarcode.substring(11, 12);
        isValidChecksum = _validateUPCAChecksum(cleanBarcode);
        break;
        
      case 13:
        type = BarcodeType.ean13;
        gs1Prefix = cleanBarcode.substring(0, 3);
        countryCode = cleanBarcode.substring(0, 2);
        
        // Australian barcodes (93X) have different structure
        if (cleanBarcode.startsWith('93')) {
          manufacturerCode = cleanBarcode.substring(2, 7);
          productCode = cleanBarcode.substring(7, 12);
        } else {
          manufacturerCode = cleanBarcode.substring(3, 8);
          productCode = cleanBarcode.substring(8, 12);
        }
        
        checkDigit = cleanBarcode.substring(12, 13);
        isValidChecksum = _validateEAN13Checksum(cleanBarcode);
        break;
        
      default:
        if (cleanBarcode.length > 14) {
          type = BarcodeType.code128; // Could be Code-128 or other format
        }
        break;
    }

    return BarcodeStructure(
      originalBarcode: barcode,
      cleanBarcode: cleanBarcode,
      type: type,
      gs1Prefix: gs1Prefix,
      countryCode: countryCode,
      manufacturerCode: manufacturerCode,
      productCode: productCode,
      checkDigit: checkDigit,
      isValidChecksum: isValidChecksum,
    );
  }

  /// Validate EAN-13 checksum using GS1 algorithm
  bool _validateEAN13Checksum(String barcode) {
    if (barcode.length != 13) return false;
    
    try {
      int sum = 0;
      for (int i = 0; i < 12; i++) {
        int digit = int.parse(barcode[i]);
        sum += (i % 2 == 0) ? digit : digit * 3;
      }
      
      int calculatedCheckDigit = (10 - (sum % 10)) % 10;
      int providedCheckDigit = int.parse(barcode[12]);
      
      return calculatedCheckDigit == providedCheckDigit;
    } catch (e) {
      return false;
    }
  }

  /// Validate EAN-8 checksum
  bool _validateEAN8Checksum(String barcode) {
    if (barcode.length != 8) return false;
    
    try {
      int sum = 0;
      for (int i = 0; i < 7; i++) {
        int digit = int.parse(barcode[i]);
        sum += (i % 2 == 0) ? digit * 3 : digit;
      }
      
      int calculatedCheckDigit = (10 - (sum % 10)) % 10;
      int providedCheckDigit = int.parse(barcode[7]);
      
      return calculatedCheckDigit == providedCheckDigit;
    } catch (e) {
      return false;
    }
  }

  /// Validate UPC-A checksum
  bool _validateUPCAChecksum(String barcode) {
    if (barcode.length != 12) return false;
    
    try {
      int sum = 0;
      for (int i = 0; i < 11; i++) {
        int digit = int.parse(barcode[i]);
        sum += (i % 2 == 0) ? digit * 3 : digit;
      }
      
      int calculatedCheckDigit = (10 - (sum % 10)) % 10;
      int providedCheckDigit = int.parse(barcode[11]);
      
      return calculatedCheckDigit == providedCheckDigit;
    } catch (e) {
      return false;
    }
  }

  Future<ProductInfo> _lookupOpenFoodFacts(String barcode, {
    BarcodeStructure? barcodeStructure,
    ExtendedBarcodeData? extendedData,
  }) async {
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
        return ProductInfo.fromOpenFoodFacts(
          json, 
          barcodeStructure: barcodeStructure,
          extendedData: extendedData,
        );
      }
    }
    
    return ProductInfo.notFound(barcodeStructure: barcodeStructure);
  }

  /// Enhanced barcode validation with support for 2D codes
  bool isValidBarcode(String barcode) {
    if (barcode.isEmpty) return false;
    
    // Remove any non-digit characters for 1D barcodes
    final digits = barcode.replaceAll(RegExp(r'[^\d]'), '');
    
    print('Validating barcode: $barcode -> $digits (length: ${digits.length})');
    
    // Check for 2D barcode patterns (GS1)
    if (barcode.contains('(') && barcode.contains(')')) {
      print('Detected 2D barcode with GS1 Application Identifiers');
      return true;
    }
    
    // Common 1D barcode lengths: Code-128, EAN-8 (8), UPC-A (12), EAN-13 (13), etc.
    final validLengths = [8, 9, 10, 11, 12, 13, 14];
    
    final isValid = validLengths.contains(digits.length);
    print('Barcode validation result: $isValid');
    
    return isValid;
  }

  /// Enhanced barcode formatting with type detection
  String formatBarcode(String barcode) {
    final digits = barcode.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check for 2D barcode
    if (barcode.contains('(') && barcode.contains(')')) {
      return barcode; // Keep GS1 formatting
    }
    
    // Add common formatting based on length
    if (digits.length == 13) {
      // EAN-13 format: 1 234567 890123
      return '${digits[0]} ${digits.substring(1, 7)} ${digits.substring(7)}';
    } else if (digits.length == 12) {
      // UPC-A format: 123456 789012
      return '${digits.substring(0, 6)} ${digits.substring(6)}';
    } else if (digits.length == 8) {
      // EAN-8 format: 1234 5678
      return '${digits.substring(0, 4)} ${digits.substring(4)}';
    }
    
    return digits;
  }

  /// Get detailed barcode information for display
  Map<String, String> getBarcodeDetails(ProductInfo productInfo) {
    final details = <String, String>{};
    final structure = productInfo.barcodeStructure;
    final extended = productInfo.extendedData;

    if (structure != null) {
      details['Type'] = structure.type.name.toUpperCase();
      details['Formatted'] = formatBarcode(structure.originalBarcode);
      
      if (structure.countryCode != null) {
        details['Country of Registration'] = productInfo.countryOfRegistration;
        details['GS1 Prefix'] = structure.countryCode!;
      }
      
      if (structure.manufacturerCode != null) {
        details['Manufacturer Code'] = structure.manufacturerCode!;
      }
      
      if (structure.productCode != null) {
        details['Product Code'] = structure.productCode!;
      }
      
      if (structure.checkDigit != null) {
        details['Check Digit'] = structure.checkDigit!;
        details['Checksum Valid'] = structure.isValidChecksum ? 'Yes' : 'No';
      }
    }

    if (extended != null) {
      if (extended.expiryDate != null) {
        details['Expiry Date'] = extended.expiryDate!.toIso8601String().split('T')[0];
      }
      
      if (extended.bestBeforeDate != null) {
        details['Best Before'] = extended.bestBeforeDate!.toIso8601String().split('T')[0];
      }
      
      if (extended.batchNumber != null) {
        details['Batch Number'] = extended.batchNumber!;
      }
      
      if (extended.lotNumber != null) {
        details['Lot Number'] = extended.lotNumber!;
      }
      
      if (extended.variableWeight != null) {
        details['Variable Weight'] = '${extended.variableWeight!.toStringAsFixed(3)} kg';
      }
      
      if (extended.serialNumber != null) {
        details['Serial Number'] = extended.serialNumber!;
      }
    }

    return details;
  }
}