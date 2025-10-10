import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/db/models/ingredient.dart';

class ReceiptScannerMlkitBackup extends StatefulWidget {
  const ReceiptScannerMlkitBackup({super.key});

  @override
  State<ReceiptScannerMlkitBackup> createState() =>
      _ReceiptScannerMlkitBackupState();
}

class _ReceiptScannerMlkitBackupState extends State<ReceiptScannerMlkitBackup> {
  List<Ingredient> _scannedItems = [];
  bool _isLoading = false;

  Future<XFile?> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        // fallback to gallery
        return await picker.pickImage(source: ImageSource.gallery);
      }
      return photo;
    } catch (e) {
      debugPrint('Image pick error: $e');
      return null;
    }
  }

  Future<String> _processImageForText(XFile imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      return recognizedText.text;
    } catch (e) {
      debugPrint('Text processing error: $e');
      return '';
    } finally {
      textRecognizer.close();
    }
  }

  List<Ingredient> _parseReceiptText(String rawText) {
    final List<Ingredient> items = [];
    final List<String> lines = rawText.split('\n');
    final RegExp itemRegex = RegExp(r'^(.*?)\s+([\d,]+\.\d{2})$');

    for (final line in lines) {
      final match = itemRegex.firstMatch(line.trim());
      if (match != null) {
        final String itemName = match.group(1)!.trim();
        if (!itemName.toLowerCase().contains('total') &&
            !itemName.toLowerCase().contains('tax')) {
          items.add(
            Ingredient(
              name: itemName,
              quantity: 1,
              weightKg: 0,
              expiry: DateTime.now().add(const Duration(days: 7)),
            ),
          );
        }
      }
    }
    return items;
  }

  void _scanReceipt() async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
      _scannedItems = [];
    });

    final imageFile = await _pickImage();
    if (imageFile == null) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No image selected or camera unavailable'),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Processing receipt...')),
    );

    final rawText = await _processImageForText(imageFile);
    debugPrint('Receipt OCR raw text length: ${rawText.length}');
    if (rawText.isNotEmpty) {
      debugPrint(
        'OCR preview: ${rawText.substring(0, rawText.length.clamp(0, 300))}',
      );
    }

    final parsedItems = _parseReceiptText(rawText);

    if (rawText.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No text recognized from the image. Try a clearer photo.',
            ),
          ),
        );
      }
    } else if (parsedItems.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not parse items from receipt. Try a different photo.',
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Found ${parsedItems.length} item(s) on receipt'),
          ),
        );
      }
    }

    setState(() {
      _scannedItems = parsedItems;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt (MLKit Backup)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.of(context).pop(_scannedItems);
            },
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _scannedItems.isEmpty
            ? const Text('Scan a receipt to get started.')
            : ListView.builder(
                itemCount: _scannedItems.length,
                itemBuilder: (context, index) {
                  final item = _scannedItems[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('Quantity: ${item.quantity}'),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanReceipt,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
