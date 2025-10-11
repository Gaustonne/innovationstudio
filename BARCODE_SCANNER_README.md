# Barcode Scanner Implementation

This document describes the barcode scanning feature implementation in the Kitchen Inventory Flutter app, specifically designed for Australian products.

## 📱 Overview

The barcode scanner allows users to quickly add items to their inventory by scanning product barcodes. The system automatically looks up product information from online databases and pre-fills item details.

## 🛠 Technical Stack

### Libraries & Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| `mobile_scanner` | ^5.0.0 | Camera-based barcode scanning |
| `http` | ^1.5.0 | API calls to product databases |
| `flutter/material.dart` | - | UI components and navigation |

### Supported Barcode Formats

- **EAN-13** (13 digits) - Most common for Australian products
- **EAN-8** (8 digits) - Smaller products
- **UPC-A** (12 digits) - North American standard
- **Code-128** - Variable length industrial barcodes

## 🏗 Architecture

### File Structure
```
lib/
├── common/
│   └── services/
│       └── barcode_service.dart          # Product lookup logic
└── features/
    └── inventory/
        └── presentation/
            └── barcode_scanner_screen.dart # Scanner UI
```

### Data Flow
```
1. User taps "Scan Barcode" button
2. Camera opens with scanning overlay
3. Mobile scanner detects barcode
4. BarcodeService validates and processes barcode
5. Multiple API calls try different barcode formats
6. Product info returned or "not found" state
7. User redirected to Add Item screen with pre-filled data
```

## 🔍 Barcode Processing Pipeline

### 1. Detection & Validation
```dart
// Scanner detects raw barcode
String rawBarcode = "9310015232350";

// Clean and validate
String cleanBarcode = rawBarcode.replaceAll(RegExp(r'\D'), '');
bool isValid = cleanBarcode.length >= 8 && cleanBarcode.length <= 14;
```

### 2. Format Variations
The system tries multiple barcode format variations to maximize success:

```dart
List<String> variations = [
  "9310015232350",      // Original
  "0009310015232350",   // Padded to 13 digits
  "009310015232350",    // Padded to 12 digits
  "9310015232350",      // Australian prefix maintained
];
```

### 3. API Lookup Process
For each variation, the system calls:
1. **Open Food Facts API** - Primary free database
2. Future: UPC Database, Woolworths API, etc.

## 🌏 Australian Product Support

### Database Sources

#### Open Food Facts (Primary)
- **URL**: `https://world.openfoodfacts.org/api/v0/product/{barcode}.json`
- **Coverage**: Good Australian product coverage
- **Cost**: Free
- **Rate Limits**: Reasonable for app usage

#### Future Sources
- **UPC Database**: Paid API with broader coverage
- **Woolworths/Coles**: Direct retailer APIs (if available)
- **Local Cache**: Store successful lookups locally

### Australian Barcode Handling
Australian products typically use the `93` country code prefix:
- Format: `93XXXXXXXXXXX` (13 digits)
- The system automatically handles variations with/without the prefix

## 📋 Product Information Extraction

### Data Fields Retrieved
```dart
class ProductInfo {
  final String? productName;    // Main product name
  final String? brand;          // Manufacturer/brand
  final String? quantity;       // Package size (e.g., "500g", "2L")
  final String? imageUrl;       // Product image
  final String? categories;     // Product categories
  final bool isFound;           // Success flag
}
```

### Size/Quantity Detection
The system extracts size information from multiple sources:
1. **API quantity field**: Direct from database
2. **Product name parsing**: Regex extraction from names
3. **Multiple field sources**: `serving_size`, `net_weight`, etc.

```dart
// Regex for size extraction from product names
RegExp(r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l|oz|lb|pack|ct)\b')
```

## 🎯 User Interface

### Scanner Screen Features
- **Camera preview** with scanning overlay
- **Visual feedback** - frame changes color during processing
- **Torch control** - flashlight button for low light
- **Manual entry fallback** - bypass scanning if needed
- **Processing indicators** - shows scanning status
- **Error handling** - user-friendly error messages

### Navigation Flow
```
Main Inventory Screen
    ↓ (Tap "Scan Barcode")
Barcode Scanner Screen
    ↓ (Barcode detected)
Product Lookup (Loading)
    ↓ (Success/Failure)
Add Item Screen (Pre-filled)
    ↓ (Save)
Back to Main Inventory
```

## ⚙️ Configuration & Setup

### Permissions Required

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan product barcodes</string>
```

### Package Installation
```bash
flutter pub add mobile_scanner
flutter pub add http  # Already included
flutter pub get
```

## 🔧 Customization Options

### Adding New Database Sources
```dart
// In BarcodeService.lookupProduct()
Future<ProductInfo> lookupProduct(String barcode) async {
  // Try Open Food Facts
  var result = await _lookupOpenFoodFacts(barcode);
  if (result.isFound) return result;
  
  // Add new source here
  result = await _lookupNewDatabase(barcode);
  if (result.isFound) return result;
  
  return ProductInfo.notFound();
}
```

### Scanner Customization
```dart
// Adjust scanning area size
Container(
  width: 300,  // Adjust width
  height: 200, // Adjust height
  decoration: BoxDecoration(
    border: Border.all(color: Colors.white, width: 3),
  ),
)
```

## 📊 Performance Considerations

### Optimization Strategies
1. **Debounced scanning** - Prevents multiple scans of same barcode
2. **Format prioritization** - Try most likely formats first
3. **Timeout handling** - 10-second API timeout
4. **Caching** - Future: Cache successful lookups
5. **Background processing** - API calls don't block UI

### Error Handling
- **Network errors**: Graceful fallback to manual entry
- **Invalid barcodes**: Format validation before processing
- **API failures**: User-friendly error messages
- **Camera issues**: Fallback to manual barcode entry

## 🧪 Testing

### Test Scenarios
1. **Australian products** with `93` prefix
2. **International products** with various prefixes
3. **Network failure** conditions
4. **Invalid barcodes** (wrong length, non-numeric)
5. **Low light conditions** (flashlight usage)

### Debug Output
Enable console logging to see detailed barcode processing:
```dart
print('Scanned barcode: $scannedValue');
print('Trying barcode variation: $testBarcode');
print('Found product: ${product['product_name']}');
```

## 🚀 Future Enhancements

### Planned Features
- [ ] **Batch scanning** - Multiple items at once
- [ ] **Offline mode** - Local database caching
- [ ] **Custom databases** - User-defined product sources
- [ ] **Nutrition data** - Extended product information
- [ ] **Price tracking** - Integration with retailer APIs
- [ ] **Inventory tracking** - Direct stock level updates

### Performance Improvements
- [ ] **Local caching** - SQLite storage for frequent products
- [ ] **Predictive loading** - Pre-load common Australian products
- [ ] **OCR fallback** - Text recognition for damaged barcodes
- [ ] **Multiple camera support** - Front/back camera switching

## 📝 License & Attribution

### Open Food Facts
This app uses the Open Food Facts database, which is:
- **License**: Open Database License (ODbL)
- **Attribution**: Data provided by Open Food Facts
- **Website**: https://openfoodfacts.org/

### Mobile Scanner
- **License**: BSD-3-Clause License
- **Repository**: https://github.com/juliansteenbakker/mobile_scanner

## 📞 Support & Troubleshooting

### Common Issues

#### "Barcode not scanning"
1. Ensure good lighting or use flashlight
2. Hold phone steady and at appropriate distance
3. Try different angles
4. Check camera permissions

#### "Product not found"
1. Try scanning again for better barcode detection
2. Use "Enter Manually" option
3. Verify barcode is from supported region
4. Check network connection

#### "Scanner won't open"
1. Check camera permissions in device settings
2. Ensure no other app is using camera
3. Restart the app

### Debug Mode
Enable detailed logging by setting debug flags in `barcode_service.dart` to see full API responses and processing details.

---

**Last Updated**: October 11, 2025  
**Version**: 1.0.0  
**Flutter SDK**: ^3.9.0