import 'package:flutter/material.dart';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/db/models/ingredient.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  List<Ingredient> _scannedItems = [];
  bool _isLoading = false;

  Future<File?> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      return File(photo.path);
    }
    return null;
  }

  Future<String> _processImageForText(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    String fullText = recognizedText.text;
    textRecognizer.close();
    return fullText;
  }

  List<Ingredient> _parseReceiptText(String rawText) {
    final List<Ingredient> items = [];
    final List<String> lines = rawText.split('\n');
    final RegExp itemRegex = RegExp(r'^(.*?)\s+([\d,]+\.\d{2})$');

    for (final line in lines) {
      final match = itemRegex.firstMatch(line.trim());
      if (match != null) {
        final String itemName = match.group(1)!.trim();
        // We don't have price in the Ingredient model, so we ignore it for now.
        // final double itemPrice = double.parse(match.group(2)!.replaceAll(',', ''));

        if (!itemName.toLowerCase().contains('total') &&
            !itemName.toLowerCase().contains('tax')) {
          items.add(
            Ingredient(
              name: itemName,
              quantity: 1, // Default quantity
              weightKg: 0, // Default weight
              expiry: DateTime.now().add(const Duration(days: 7)), // Default expiry
            ),
          );
        }
      }
    }
    return items;
  }

  void _scanReceipt() async {
    setState(() {
      _isLoading = true;
      _scannedItems = [];
    });

    final imageFile = await _pickImage();
    if (imageFile == null) {
      setState(() => _isLoading = false);
      return;
    }

    final rawText = await _processImageForText(imageFile);
    final parsedItems = _parseReceiptText(rawText);

    setState(() {
      _scannedItems = parsedItems;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
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
