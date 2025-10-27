import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import '../../common/db/models/ingredient.dart';
import '../../common/db/collections/inventory_store.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class ScannedIngredient {
  final String name;
  final double confidence;
  final String imagePath;
  final bool isEdited;
  
  ScannedIngredient({
    required this.name,
    required this.confidence,
    required this.imagePath,
    this.isEdited = false,
  });

  ScannedIngredient copyWith({
    String? name,
    double? confidence,
    String? imagePath,
    bool? isEdited,
  }) {
    return ScannedIngredient(
      name: name ?? this.name,
      confidence: confidence ?? this.confidence,
      imagePath: imagePath ?? this.imagePath,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;

  // Multi-capture mode
  bool _isMultiMode = false;
  final List<ScannedIngredient> _scannedIngredients = [];

  // Azure prediction results
  String? _predictedLabel;
  double? _confidence;
  bool _isProcessing = false;

  final String _predictionKey = '4jFsYRIQmKpBGgRYE9oebAbWQAD6UGuYBDSaoUVpiknSjnozVdfxJQQJ99BJACi0881XJ3w3AAAIACOGvhXu';
  final String _endpoint = 'https://customvisionkimleng-prediction.cognitiveservices.azure.com/';
  final String _projectId = '160499c0-eaed-47c2-8191-8cee61ce9ef8';
  final String _iterationName = 'Iteration3';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      _controller = CameraController(backCamera, ResolutionPreset.medium);
      _initializeControllerFuture = _controller!.initialize();
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Capture the image and send it to Azure Custom Vision
  Future<void> _captureAndPredict() async {
    if (_controller == null) return;

    try {
      setState(() {
        _isProcessing = true;
        _predictedLabel = null;
        _confidence = null;
      });

      await _initializeControllerFuture;
      final image = await _controller!.takePicture();

      // Save to app directory
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final savedImage = await File(image.path).copy(imagePath);
      setState(() => _capturedImage = XFile(savedImage.path));

      // Send image to Azure Custom Vision Prediction API
      final predictionUrl =
          '$_endpoint/customvision/v3.0/Prediction/$_projectId/classify/iterations/$_iterationName/image';

      final bytes = await File(savedImage.path).readAsBytes();
      final response = await http.post(
        Uri.parse(predictionUrl),
        headers: {
          'Content-Type': 'application/octet-stream',
          'Prediction-Key': _predictionKey,
        },
        body: bytes,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        // Assuming you used a classification project
        if (result['predictions'] != null && result['predictions'].isNotEmpty) {
          final topPrediction = result['predictions'][0];
          final predictedName = topPrediction['tagName'];
          final confidence = topPrediction['probability'];
          
          setState(() {
            _predictedLabel = predictedName;
            _confidence = confidence;
          });

          if (_isMultiMode) {
            // Add to scanned ingredients list
            final scannedIngredient = ScannedIngredient(
              name: predictedName,
              confidence: confidence,
              imagePath: savedImage.path,
            );
            
            setState(() {
              _scannedIngredients.add(scannedIngredient);
            });
            
            _showIngredientAddedSnackBar(scannedIngredient);
          } else {
            // Single mode - show confirmation dialog
            _showSingleIngredientDialog(predictedName, confidence, savedImage.path);
          }
        }
      } else {
        debugPrint('Prediction API error: ${response.statusCode} ${response.body}');
        _showError('Failed to analyze image. Please try again.');
      }

      setState(() => _isProcessing = false);
    } catch (e) {
      debugPrint('Error capturing or predicting image: $e');
      setState(() => _isProcessing = false);
      _showError('Error capturing image: $e');
    }
  }

  void _showSingleIngredientDialog(String ingredientName, double confidence, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingredient Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Detection results
            Text(
              ingredientName.toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            Text(
              'Confidence: ${(confidence * 100).toInt()}%',
              style: TextStyle(
                color: _getConfidenceColor(confidence),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditIngredientDialog(
                ScannedIngredient(
                  name: ingredientName,
                  confidence: confidence,
                  imagePath: imagePath,
                ),
                (edited) => _addSingleIngredientToInventory(edited),
              );
            },
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addSingleIngredientToInventory(ScannedIngredient(
                name: ingredientName,
                confidence: confidence,
                imagePath: imagePath,
              ));
            },
            child: const Text('Add to Inventory'),
          ),
        ],
      ),
    );
  }

  void _showIngredientAddedSnackBar(ScannedIngredient ingredient) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white54),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(ingredient.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${ingredient.name} scanned',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${(ingredient.confidence * 100).toInt()}% confidence • ${_scannedIngredients.length} total',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMultiModeResults() {
    if (_scannedIngredients.isEmpty) {
      _showError('No ingredients scanned yet');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${_scannedIngredients.length} Ingredients Scanned'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _scannedIngredients.length,
            itemBuilder: (context, index) {
              final ingredient = _scannedIngredients[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(ingredient.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(
                    ingredient.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: ingredient.isEdited ? TextDecoration.underline : null,
                    ),
                  ),
                  subtitle: Text(
                    '${(ingredient.confidence * 100).toInt()}% confidence${ingredient.isEdited ? ' • Edited' : ''}',
                    style: TextStyle(
                      color: _getConfidenceColor(ingredient.confidence),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditIngredientDialog(
                          ingredient,
                          (edited) {
                            setState(() {
                              _scannedIngredients[index] = edited;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _scannedIngredients.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Scanning'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addAllIngredientsToInventory();
            },
            child: Text('Add All (${_scannedIngredients.length})'),
          ),
        ],
      ),
    );
  }

  void _showEditIngredientDialog(ScannedIngredient ingredient, Function(ScannedIngredient) onSave) {
    final TextEditingController nameController = TextEditingController(text: ingredient.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Ingredient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(ingredient.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ingredient Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final editedName = nameController.text.trim();
              if (editedName.isNotEmpty) {
                final edited = ingredient.copyWith(
                  name: editedName,
                  isEdited: editedName != ingredient.name,
                );
                onSave(edited);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSingleIngredientToInventory(ScannedIngredient scannedIngredient) async {
    try {
      final ingredient = Ingredient(
        name: scannedIngredient.name,
        quantity: 1,
        weightKg: _estimateWeightForIngredient(scannedIngredient.name),
        expiry: _estimateExpiryForIngredient(scannedIngredient.name),
        costAud: null, // No cost for fresh produce
      );
      
      await InventoryStore().insert(ingredient);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${scannedIngredient.name} added to inventory'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate back after successful addition
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding ingredient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addAllIngredientsToInventory() async {
    try {
      int addedCount = 0;
      
      for (final scannedIngredient in _scannedIngredients) {
        final ingredient = Ingredient(
          name: scannedIngredient.name,
          quantity: 1,
          weightKg: _estimateWeightForIngredient(scannedIngredient.name),
          expiry: _estimateExpiryForIngredient(scannedIngredient.name),
          costAud: null, // No cost for fresh produce
        );
        
        await InventoryStore().insert(ingredient);
        addedCount++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $addedCount ingredients to inventory'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Clear scanned ingredients and navigate back
        setState(() {
          _scannedIngredients.clear();
        });
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding ingredients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DateTime _estimateExpiryForIngredient(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    
    if (lowerName.contains('lettuce') || lowerName.contains('spinach') || lowerName.contains('herbs')) {
      return DateTime.now().add(const Duration(days: 3)); // Leafy greens
    } else if (lowerName.contains('apple') || lowerName.contains('orange') || lowerName.contains('banana')) {
      return DateTime.now().add(const Duration(days: 7)); // Fruits
    } else if (lowerName.contains('carrot') || lowerName.contains('potato') || lowerName.contains('onion')) {
      return DateTime.now().add(const Duration(days: 14)); // Root vegetables
    } else if (lowerName.contains('tomato') || lowerName.contains('pepper')) {
      return DateTime.now().add(const Duration(days: 5)); // Fresh vegetables
    }
    
    return DateTime.now().add(const Duration(days: 7)); // Default
  }

  double _estimateWeightForIngredient(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    
    if (lowerName.contains('apple') || lowerName.contains('orange')) {
      return 0.2; // ~200g per fruit
    } else if (lowerName.contains('banana')) {
      return 0.15; // ~150g per banana
    } else if (lowerName.contains('lettuce')) {
      return 0.3; // ~300g per head
    } else if (lowerName.contains('carrot')) {
      return 0.1; // ~100g per carrot
    }
    
    return 0.2; // Default 200g
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Ingredients'),
        backgroundColor: Colors.teal.shade700,
        actions: [
          // Multi-mode toggle
          Switch(
            value: _isMultiMode,
            onChanged: (value) {
              setState(() {
                _isMultiMode = value;
                if (!value) {
                  _scannedIngredients.clear();
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Column(
                    children: [
                      // Mode indicator
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: _isMultiMode ? Colors.orange.shade100 : Colors.blue.shade100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isMultiMode ? Icons.camera_alt : Icons.center_focus_strong,
                              color: _isMultiMode ? Colors.orange.shade700 : Colors.blue.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isMultiMode 
                                  ? 'Multi-Mode: ${_scannedIngredients.length} items scanned'
                                  : 'Single Mode',
                              style: TextStyle(
                                color: _isMultiMode ? Colors.orange.shade700 : Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Camera preview
                      Expanded(
                        flex: 3,
                        child: Stack(
                          children: [
                            CameraPreview(_controller!),
                            
                            // Multi-mode results button
                            if (_isMultiMode && _scannedIngredients.isNotEmpty)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: FloatingActionButton.extended(
                                  heroTag: "results",
                                  onPressed: _showMultiModeResults,
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  icon: const Icon(Icons.list),
                                  label: Text('${_scannedIngredients.length}'),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Captured image preview
                      Expanded(
                        flex: 2,
                        child: _capturedImage == null
                            ? const Center(
                                child: Text(
                                  'No image captured yet',
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : Image.file(File(_capturedImage!.path)),
                      ),

                      // Azure prediction results
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        )
                      else if (_predictedLabel != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Prediction: $_predictedLabel\nConfidence: ${(_confidence! * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Capture button
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _captureAndPredict,
                                icon: _isProcessing 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt),
                                label: Text(_isProcessing 
                                    ? 'Processing...' 
                                    : 'Capture & Predict'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isMultiMode 
                                      ? Colors.orange.shade700 
                                      : Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ),
                            
                            // Multi-mode results button (alternative placement)
                            if (_isMultiMode && _scannedIngredients.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _showMultiModeResults,
                                icon: const Icon(Icons.list),
                                label: Text('${_scannedIngredients.length}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(80, 48),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }
}