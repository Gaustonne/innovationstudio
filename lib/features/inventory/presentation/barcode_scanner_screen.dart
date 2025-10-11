import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  final MobileScannerController _controller = MobileScannerController();
  final BarcodeService _barcodeService = BarcodeService();
  
  bool _isProcessing = false;
  bool _hasScanned = false;
  String? _lastScannedBarcode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String barcode) async {
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

      // Lookup product information
      final productInfo = await _barcodeService.lookupProduct(barcode);
      
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
          Navigator.of(context).pop(result);
        }
      } else {
        // Product not found, but still return the barcode
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
    );
  }

  void _showProductNotFound(BarcodeScannerResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${_barcodeService.formatBarcode(result.barcode)}'),
            const SizedBox(height: 16),
            const Text('This product was not found in our database. You can still add it manually.'),
          ],
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
          MobileScanner(
            controller: _controller,
            fit: BoxFit.contain,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              print('Detected ${barcodes.length} barcodes');
              
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !_isProcessing && !_hasScanned) {
                  final scannedValue = barcode.rawValue!;
                  final cleanValue = scannedValue.replaceAll(RegExp(r'\D'), '');
                  
                  print('Barcode type: ${barcode.type}');
                  print('Scanned barcode: $scannedValue');
                  print('Clean barcode: $cleanValue');
                  print('Barcode length: ${cleanValue.length}');
                  
                  // Validate barcode length (should be 8-14 digits for products)
                  if (cleanValue.length >= 8 && cleanValue.length <= 14) {
                    print('Processing valid barcode: $cleanValue');
                    _processBarcode(cleanValue);
                    break;
                  } else {
                    print('Invalid barcode length: ${cleanValue.length}, skipping');
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
            final torchEnabled = value.torchState == TorchState.on;
            return Icon(torchEnabled ? Icons.flash_off : Icons.flash_on);
          },
        ),
      ),
    );
  }
}