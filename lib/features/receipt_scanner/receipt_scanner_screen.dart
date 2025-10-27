import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../common/db/models/ingredient.dart';
import '../../../common/db/collections/inventory_store.dart';
import '../inventory/presentation/item_card.dart';
import '../inventory/presentation/add_item.dart';
import '../inventory/presentation/inventory.dart';

String get _kImgbbApiKey => dotenv.env['IMGBB_API_KEY'] ?? '';
String get _kAzureEndpoint => dotenv.env['AZURE_ENDPOINT'] ?? '';
String get _kAzureApiKey => dotenv.env['AZURE_API_KEY'] ?? '';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  List<Ingredient> _scannedItems = [];
  bool _isLoading = false;
  bool _useSample = false;
  bool _envLoaded = false;

  Future<XFile?> _pickImage() async {
    try {
      final picker = ImagePicker();
      // On some Android versions (9+), HEIC/HEIF images are only returned
      // if you request a size modification. Provide maxWidth and imageQuality
      // so gallery/camera picks return a compatible image.
      const double maxWidth = 4000;
      const int imageQuality = 100;

      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
      );
      if (photo == null) {
        return await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: maxWidth,
          imageQuality: imageQuality,
        );
      }
      return photo;
    } catch (e) {
      debugPrint('Image pick error: $e');
      return null;
    }
  }

  Future<String?> _uploadToImgbb(XFile file) async {
    if (_kImgbbApiKey.isEmpty) return null;
    try {
      final bytes = await file.readAsBytes();

      // Use multipart/form-data and send the image as a named file field.
      final uri = Uri.parse(
        'https://api.imgbb.com/1/upload?key=${_kImgbbApiKey}',
      );
      final request = http.MultipartRequest('POST', uri);

      // imgbb accepts an "image" field. Use the original bytes; when possible
      // callers should convert to JPEG if needed (optional enhancement).
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'upload.jpg',
      );
      request.files.add(multipartFile);

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> j =
            jsonDecode(resp.body) as Map<String, dynamic>;
        return j['data']?['url'] as String?;
      }
      debugPrint(
        'imgbb multipart upload failed: ${resp.statusCode} ${resp.body}',
      );
    } catch (e) {
      debugPrint('imgbb multipart upload error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _analyzeWithAzure(String imageUrl) async {
    if (_kAzureEndpoint.isEmpty || _kAzureApiKey.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse(
        '$_kAzureEndpoint/documentintelligence/documentModels/prebuilt-receipt:analyze?api-version=2024-11-30',
      );
      final resp = await http.post(
        uri,
        headers: {
          'Ocp-Apim-Subscription-Key': _kAzureApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'urlSource': imageUrl}),
      );
      if (resp.statusCode == 202) {
        final opLocation = resp.headers['operation-location'];
        if (opLocation == null) return null;
        for (var i = 0; i < 20; i++) {
          await Future.delayed(Duration(seconds: 1 << i));
          final r = await http.get(
            Uri.parse(opLocation),
            headers: {'Ocp-Apim-Subscription-Key': _kAzureApiKey},
          );
          if (r.statusCode == 200) {
            final Map<String, dynamic> j =
                jsonDecode(r.body) as Map<String, dynamic>;
            final status = (j['status'] as String?)?.toLowerCase() ?? '';
            if (status == 'succeeded' || status == 'failed') return j;
          }
        }
      } else if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        debugPrint(
          'Azure analyze start failed: ${resp.statusCode} ${resp.body}',
        );
      }
    } catch (e) {
      debugPrint('Azure analyze error: $e');
    }
    return null;
  }

  List<Ingredient> _itemsFromAzureResult(Map<String, dynamic> j) {
    final List<Ingredient> items = [];
    try {
      final docs = (j['analyzeResult']?['documents'] as List?) ?? [];
      if (docs.isNotEmpty) {
        final fields = docs.first['fields'] as Map?;
        final itemsField = fields?['Items'];
        if (itemsField != null && itemsField['valueArray'] is List) {
          for (final it in itemsField['valueArray']) {
            final itemData = it['valueObject'] as Map?;
            final name = itemData?['Description']?['valueString'] as String?;
            int qty;
            double weight;
            if (itemData?['QuantityUnit']?['valueString'] == 'kg') {
              weight = itemData?['Quantity']?['valueNumber'];
              qty = 1;
            } else {
              qty = itemData?['Quantity']?['valueNumber'] ?? 1;
              weight = 0;
            }
            if (name != null) {
              // Extract price if available
              final price = itemData?['TotalPrice']?['valueNumber'] as double?;
              
              items.add(
                Ingredient(
                  name: name,
                  quantity: qty,
                  weightKg: weight,
                  // sentinel "unset" expiry; user must set before adding
                  expiry: DateTime.fromMillisecondsSinceEpoch(0),
                  costAud: price, // Optional field - can be null
                ),
              );
            }
          }
          return items;
        }
      }

      final content = j['analyzeResult']?['content'] as String?;
      if (content != null && content.isNotEmpty) {
        final lines = content.split('\n');
        for (final l in lines) {
          final trimmed = l.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed.toLowerCase().contains('total') ||
              trimmed.toLowerCase().contains('gst') ||
              trimmed.contains('\u001f')) {
            continue;
          }
          if (RegExp(r'^\$?\d+[.,]?\d*').hasMatch(trimmed)) continue;
          
          // Try to extract price from the line if it contains both item name and price
          double? extractedPrice;
          String cleanName = trimmed;
          final priceMatch = RegExp(r'(.+?)\s+\$?(\d+\.?\d*)$').firstMatch(trimmed);
          if (priceMatch != null) {
            cleanName = priceMatch.group(1)?.trim() ?? trimmed;
            extractedPrice = double.tryParse(priceMatch.group(2) ?? '');
          }
          
          items.add(
            Ingredient(
              name: cleanName,
              quantity: 1,
              weightKg: 0,
              // sentinel unset expiry
              expiry: DateTime.fromMillisecondsSinceEpoch(0),
              costAud: extractedPrice, // Optional field - can be null
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Parsing azure result failed: $e');
    }
    return items;
  }

  Future<void> _scanAndAnalyze() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isLoading = true;
      _scannedItems = [];
    });

    if (_useSample) {
      // Load bundled sample JSON if present in assets or use the example provided by the user.
      // For now, attempt to load an in-repo sample file path relative to project root via rootBundle
      try {
        final sample = await DefaultAssetBundle.of(
          context,
        ).loadString('assets/sample_azure_receipt.json');
        final Map<String, dynamic> j =
            jsonDecode(sample) as Map<String, dynamic>;
        final parsed = _itemsFromAzureResult(j);
        setState(() {
          _scannedItems = parsed;
          _isLoading = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Loaded ${parsed.length} items from sample JSON'),
          ),
        );
      } catch (e) {
        debugPrint('Sample load failed: $e');
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Sample JSON load failed')),
        );
      }
      return;
    }

    final imageFile = await _pickImage();
    if (imageFile == null) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('No image selected')),
      );
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('Uploading image...')));
    final imageUrl = await _uploadToImgbb(imageFile);
    if (imageUrl == null) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Image upload failed')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Analyzing... This may take a moment'),
        duration: Duration(seconds: 10),
      ),
    );
    final result = await _analyzeWithAzure(imageUrl);
    if (result == null) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Document analysis failed')),
      );
      return;
    }

    final parsed = _itemsFromAzureResult(result);
    setState(() {
      _scannedItems = parsed;
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _ensureEnvLoaded();
  }

  Future<void> _ensureEnvLoaded() async {
    try {
      // If dotenv hasn't been loaded yet, try to load .env from project root.
      if (dotenv.env.isEmpty) {
        await dotenv.load(fileName: '.env');
      }
    } catch (e) {
      debugPrint('dotenv load failed: $e');
    } finally {
      if (mounted) setState(() => _envLoaded = true);
    }
  }

  Widget _buildEnvBanner() {
    if (!_envLoaded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        color: Colors.grey.shade200,
        child: const Text('Loading environment...'),
      );
    }

    final liveEnabled =
        _kImgbbApiKey.isNotEmpty &&
        _kAzureEndpoint.isNotEmpty &&
        _kAzureApiKey.isNotEmpty;

    if (liveEnabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          children: const [
            Icon(Icons.cloud_done, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Live receipt analysis enabled')),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        children: const [
          Icon(Icons.cloud_off, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('Using sample JSON or missing API keys')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt (AI)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: _useSample,
                    onChanged: (v) => setState(() => _useSample = v ?? false),
                    title: const Text('Use sample JSON (no API keys required)'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildEnvBanner(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _scannedItems.isEmpty
                  ? const Center(child: Text('No items scanned yet'))
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _scannedItems.length,
                      itemBuilder: (context, index) {
                        final it = _scannedItems[index];
                        return Dismissible(
                          key: ValueKey(it.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.delete_forever, color: Colors.white),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            final messenger = ScaffoldMessenger.of(context);
                            final confirmed =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (dctx) => AlertDialog(
                                    title: const Text('Remove scanned item?'),
                                    content: Text(
                                      'Remove "${it.name}" from scanned items?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (confirmed) {
                              setState(() => _scannedItems.removeAt(index));
                              messenger.showSnackBar(
                                SnackBar(content: Text('Removed "${it.name}"')),
                              );
                              return true;
                            }
                            return false;
                          },
                          child: InkWell(
                            onTap: () async {
                              final result = await Navigator.of(context)
                                  .push<dynamic>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddIngredientScreen(ingredient: it),
                                    ),
                                  );
                              if (result == null) return;
                              if (result is EditResult) {
                                if (result.deletedId != null) {
                                  setState(
                                    () => _scannedItems.removeWhere(
                                      (s) => s.id == result.deletedId,
                                    ),
                                  );
                                } else if (result.item != null) {
                                  final updated = result.item!;
                                  final idx = _scannedItems.indexWhere(
                                    (s) => s.id == updated.id,
                                  );
                                  if (idx != -1) {
                                    setState(
                                      () => _scannedItems[idx] = updated,
                                    );
                                  }
                                }
                              } else if (result is Ingredient) {
                                final idx = _scannedItems.indexWhere(
                                  (s) => s.id == result.id,
                                );
                                if (idx != -1) {
                                  setState(() => _scannedItems[idx] = result);
                                }
                              }
                            },
                            child: ItemCard(item: it),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _scanAndAnalyze,
                    child: const Text('Scan Receipt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            final store = InventoryStore();
                            if (_scannedItems.isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('No items to add'),
                                ),
                              );
                              return;
                            }
                            // If there are unset expiries, notify user they will be prompted to set them.
                            if (_scannedItems.any(
                              (s) => s.expiry.millisecondsSinceEpoch == 0,
                            )) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Some items are missing expiry dates — you will be prompted to set them before adding',
                                  ),
                                ),
                              );
                            }
                            // Ensure all items have expiry set (sentinel has msSinceEpoch == 0)
                            while (true) {
                              final idxUnset = _scannedItems.indexWhere(
                                (s) => s.expiry.millisecondsSinceEpoch == 0,
                              );
                              if (idxUnset == -1) break;
                              // prompt user to edit the item
                              final toEdit = _scannedItems[idxUnset];
                              final res = await Navigator.of(context)
                                  .push<dynamic>(
                                    MaterialPageRoute(
                                      builder: (_) => AddIngredientScreen(
                                        ingredient: toEdit,
                                      ),
                                    ),
                                  );
                              if (res == null) {
                                // user cancelled editing; abort insertion
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cancelled - set expiry for all items before adding',
                                    ),
                                  ),
                                );
                                setState(() => _isLoading = false);
                                return;
                              }
                              if (res is EditResult) {
                                if (res.deletedId != null) {
                                  setState(
                                    () => _scannedItems.removeAt(idxUnset),
                                  );
                                  continue; // find next unset
                                } else if (res.item != null) {
                                  setState(
                                    () => _scannedItems[idxUnset] = res.item!,
                                  );
                                }
                              } else if (res is Ingredient) {
                                setState(() => _scannedItems[idxUnset] = res);
                              }
                            }

                            setState(() => _isLoading = true);
                            for (final it in List<Ingredient>.from(
                              _scannedItems,
                            )) {
                              await store.insert(it);
                            }
                            setState(() => _isLoading = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added ${_scannedItems.length} items to inventory',
                                ),
                              ),
                            );
                            // Notify inventory view to reload
                            inventoryRefreshNotifier.value =
                                inventoryRefreshNotifier.value + 1;
                            activePageNotifier.value = InventoryPage.main;
                            // Pop back to the app root (inventory home)
                            navigator.popUntil((route) => route.isFirst);
                          },
                    child: const Text('Use Items'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
