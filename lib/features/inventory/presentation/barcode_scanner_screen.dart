import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;
import '../../../common/services/barcode_service.dart';
import '../../../common/db/models/ingredient.dart';

class BarcodeScannerResult {
  final String barcode;
  final ProductInfo productInfo;
  final Ingredient? suggestedIngredient;

  const BarcodeScannerResult({
    required this.barcode,
    required this.productInfo,
    this.suggestedIngredient,
  });
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final scanner.MobileScannerController _controller = scanner.MobileScannerController();
  final BarcodeService _barcodeService = BarcodeService();
  
  bool _isProcessing = false;
  bool _hasScanned = false;
  String? _lastScannedBarcode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String barcode, {String? rawBarcodeData}) async {
    if (_isProcessing || _hasScanned || barcode == _lastScannedBarcode) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
      _lastScannedBarcode = barcode;
    });

    try {
      // Validate barcode format
      if (!_barcodeService.isValidBarcode(barcode)) {
        _showError('Invalid barcode format');
        return;
      }

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Looking up product...'),
              ],
            ),
          ),
        );
      }

      // Lookup product information with raw barcode data for 2D codes
      final productInfo = await _barcodeService.lookupProduct(barcode, rawBarcodeData: rawBarcodeData);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (productInfo.isFound) {
        // Create suggested ingredient from product info
        final suggestedIngredient = _createSuggestedIngredient(productInfo);
        
        final result = BarcodeScannerResult(
          barcode: barcode,
          productInfo: productInfo,
          suggestedIngredient: suggestedIngredient,
        );
        
        if (mounted) {
          _showProductFound(result);
        }
      } else {
        // Product not found, but still return the barcode with structure info
        final result = BarcodeScannerResult(
          barcode: barcode,
          productInfo: productInfo,
        );
        
        if (mounted) {
          _showProductNotFound(result);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        _showError('Failed to lookup product: $e');
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Ingredient _createSuggestedIngredient(ProductInfo productInfo) {
    // Extract numeric quantity if possible
    double? weightKg;
    int quantity = 1;
    
    final quantityStr = productInfo.displayQuantity;
    if (quantityStr != null) {
      // Try to extract weight in grams/kg
      final weightMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l)', caseSensitive: false)
          .firstMatch(quantityStr);
      
      if (weightMatch != null) {
        final value = double.tryParse(weightMatch.group(1) ?? '');
        final unit = weightMatch.group(2)?.toLowerCase();
        
        if (value != null && unit != null) {
          switch (unit) {
            case 'kg':
            case 'l':
              weightKg = value;
              break;
            case 'g':
            case 'ml':
              weightKg = value / 1000;
              break;
          }
        }
      }
    }

    return Ingredient(
      name: productInfo.displayName,
      quantity: quantity,
      weightKg: weightKg ?? 1.0,
      expiry: DateTime.now().add(const Duration(days: 7)), // Default 7 days
      costAud: productInfo.estimatedPrice,
    );
  }

  void _showProductFound(BarcodeScannerResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.productInfo.displayName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              if (result.productInfo.imageUrl != null && result.productInfo.imageUrl!.isNotEmpty) ...[
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        result.productInfo.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / 
                                    loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Image not available',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // No image placeholder
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade100,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No image available',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Product Details
              _buildDetailRow('Barcode', _barcodeService.formatBarcode(result.barcode)),
              
              if (result.productInfo.brand != null)
                _buildDetailRow('Brand', result.productInfo.brand!),
              
              if (result.productInfo.displayQuantity != null)
                _buildDetailRow('Quantity', result.productInfo.displayQuantity!),
              
              // Price Information
              if (result.productInfo.estimatedPrice != null) ...[
                _buildDetailRow('Estimated Price', 
                  '\$${result.productInfo.estimatedPrice!.toStringAsFixed(2)} ${result.productInfo.currency ?? 'AUD'}'),
                if (result.productInfo.priceSource != null)
                  _buildDetailRow('Price Source', _formatPriceSource(result.productInfo.priceSource!)),
              ],
              
              if (result.productInfo.categories != null)
                _buildDetailRow('Categories', result.productInfo.categories!),
              
              // Barcode Structure Info
              if (result.productInfo.barcodeStructure != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Barcode Analysis',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildDetailRow('Type', result.productInfo.barcodeStructure!.type.name.toUpperCase()),
                _buildDetailRow('Country', result.productInfo.countryOfRegistration),
                if (result.productInfo.barcodeStructure!.isValidChecksum)
                  _buildDetailRow('Checksum', '✅ Valid')
                else
                  _buildDetailRow('Checksum', '❌ Invalid'),
              ],
              
              // Extended Data (from 2D barcodes)
              if (result.productInfo.extendedData != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Additional Data',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (result.productInfo.extendedData!.expiryDate != null)
                  _buildDetailRow('Expiry Date', 
                    result.productInfo.extendedData!.expiryDate!.toIso8601String().split('T')[0]),
                if (result.productInfo.extendedData!.batchNumber != null)
                  _buildDetailRow('Batch Number', result.productInfo.extendedData!.batchNumber!),
                if (result.productInfo.extendedData!.variableWeight != null)
                  _buildDetailRow('Variable Weight', 
                    '${result.productInfo.extendedData!.variableWeight!.toStringAsFixed(3)} kg'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Scan Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(result);
            },
            child: const Text('Add to Inventory'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPriceSource(String source) {
    switch (source) {
      case 'category_estimation':
        return 'Category Analysis';
      case 'product_name_analysis':
        return 'Product Name Analysis';
      case 'brand_analysis':
        return 'Brand Analysis';
      case 'api_lookup':
        return 'Online Database';
      case 'barcode_data':
        return 'Barcode Data';
      default:
        return 'Estimation';
    }
  }

  List<Widget> _getPricingGuidance(String country) {
    List<String> suggestions = [];
    
    switch (country) {
      case 'Australia':
        suggestions = [
          '• Australian products typically range \$2-\$15',
          '• Store brands (Coles/Woolworths) are 20-30% cheaper',
          '• Premium/organic products cost 30-50% more',
          '• Check product size for accurate cost per unit',
        ];
        break;
      case 'USA & Canada':
        suggestions = [
          '• Imported products may have premium pricing',
          '• Convert pricing from USD/CAD to AUD',
          '• Factor in import duties and shipping costs',
        ];
        break;
      case 'New Zealand':
        suggestions = [
          '• NZ products similar to Australian pricing',
          '• May have slight premium due to import costs',
        ];
        break;
      default:
        suggestions = [
          '• International products may have premium pricing',
          '• Check for local equivalents for comparison',
          '• Factor in import costs and currency conversion',
        ];
    }
    
    return suggestions.map((suggestion) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        suggestion,
        style: const TextStyle(fontSize: 13),
      ),
    )).toList();
  }

  void _showProductNotFound(BarcodeScannerResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This product was not found in our database, but we can still analyze the barcode:'),
              const SizedBox(height: 16),
              
              // Barcode Details
              _buildDetailRow('Barcode', _barcodeService.formatBarcode(result.barcode)),
              
              // Barcode Structure Info
              if (result.productInfo.barcodeStructure != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Barcode Analysis',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildDetailRow('Type', result.productInfo.barcodeStructure!.type.name.toUpperCase()),
                _buildDetailRow('Country', result.productInfo.countryOfRegistration),
                if (result.productInfo.barcodeStructure!.isValidChecksum)
                  _buildDetailRow('Checksum', '✅ Valid')
                else
                  _buildDetailRow('Checksum', '❌ Invalid'),
                
                if (result.productInfo.barcodeStructure!.manufacturerCode != null)
                  _buildDetailRow('Manufacturer Code', result.productInfo.barcodeStructure!.manufacturerCode!),
                if (result.productInfo.barcodeStructure!.productCode != null)
                  _buildDetailRow('Product Code', result.productInfo.barcodeStructure!.productCode!),
              ],
              
              // Extended Data (from 2D barcodes)
              if (result.productInfo.extendedData != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Additional Data',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (result.productInfo.extendedData!.expiryDate != null)
                  _buildDetailRow('Expiry Date', 
                    result.productInfo.extendedData!.expiryDate!.toIso8601String().split('T')[0]),
                if (result.productInfo.extendedData!.batchNumber != null)
                  _buildDetailRow('Batch Number', result.productInfo.extendedData!.batchNumber!),
                if (result.productInfo.extendedData!.variableWeight != null)
                  _buildDetailRow('Variable Weight', 
                    '${result.productInfo.extendedData!.variableWeight!.toStringAsFixed(3)} kg'),
              ],
              
              const SizedBox(height: 16),
              
              // Pricing guidance
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monetization_on, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Pricing Guidance',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._getPricingGuidance(result.productInfo.countryOfRegistration),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              const Text('You can still add this item manually to your inventory.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Scan Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(result);
            },
            child: const Text('Add Manually'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            _resetScanner();
          },
        ),
      ),
    );
    
    _resetScanner();
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
      _lastScannedBarcode = null;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Stack(
        children: [
          // Camera preview
          scanner.MobileScanner(
            controller: _controller,
            fit: BoxFit.contain,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              print('Detected ${barcodes.length} barcodes');
              
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !_isProcessing && !_hasScanned) {
                  final scannedValue = barcode.rawValue!;
                  final rawData = barcode.displayValue; // May contain additional GS1 data
                  
                  print('Barcode type: ${barcode.type}');
                  print('Scanned barcode: $scannedValue');
                  print('Raw barcode data: $rawData');
                  
                  // Handle different barcode types
                  if (rawData?.contains('(') == true && rawData?.contains(')') == true) {
                    // 2D barcode with GS1 Application Identifiers
                    print('Processing 2D barcode with additional data');
                    
                    // Extract GTIN from GS1 data or use raw value
                    String gtin = scannedValue;
                    if (rawData?.contains('(01)') == true) {
                      final gtinMatch = RegExp(r'\(01\)(\d{14})').firstMatch(rawData!);
                      if (gtinMatch != null) {
                        gtin = gtinMatch.group(1)!;
                        // Convert 14-digit GTIN to 13-digit EAN if needed
                        if (gtin.length == 14 && gtin.startsWith('0')) {
                          gtin = gtin.substring(1);
                        }
                      }
                    }
                    
                    print('Processing 2D barcode with GTIN: $gtin');
                    _processBarcode(gtin, rawBarcodeData: rawData);
                    break;
                  } else {
                    // Standard 1D barcode
                    final cleanValue = scannedValue.replaceAll(RegExp(r'\D'), '');
                    print('Clean barcode: $cleanValue');
                    print('Barcode length: ${cleanValue.length}');
                    
                    // Validate barcode length (should be 8-14 digits for products)
                    if (cleanValue.length >= 8 && cleanValue.length <= 14) {
                      print('Processing valid 1D barcode: $cleanValue');
                      _processBarcode(cleanValue);
                      break;
                    } else {
                      print('Invalid barcode length: ${cleanValue.length}, skipping');
                    }
                  }
                }
              }
            },
          ),
          
          // Overlay with scanning area
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Stack(
              children: [
                // Create a hole in the overlay for the scanning area
                Center(
                  child: Container(
                    width: 300,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing ? Colors.green : Colors.white, 
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                
                // Instructions
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          _isProcessing 
                            ? 'Processing barcode...' 
                            : 'Position the barcode within the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isProcessing ? Colors.green : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!_isProcessing) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the flashlight button if you need more light',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Manual entry button
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : () {
                        Navigator.of(context).pop(
                          const BarcodeScannerResult(
                            barcode: '',
                            productInfo: ProductInfo(isFound: false),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Enter Manually'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _controller.toggleTorch(),
        child: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, child) {
            final torchEnabled = value.torchState == scanner.TorchState.on;
            return Icon(torchEnabled ? Icons.flash_off : Icons.flash_on);
          },
        ),
      ),
    );
  }
}