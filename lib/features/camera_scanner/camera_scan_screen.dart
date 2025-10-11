import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;

  // ML Kit results
  List<ImageLabel> _labels = [];
  bool _isProcessing = false;

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

  /// Capture the image and run ML Kit label detection
  Future<void> _captureAndDetect() async {
    if (_controller == null) return;

    try {
      setState(() {
        _isProcessing = true;
        _labels = [];
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

      // Run ML Kit label detection
      final inputImage = InputImage.fromFilePath(savedImage.path);
      final options = ImageLabelerOptions(confidenceThreshold: 0.5);
      final labeler = ImageLabeler(options: options);

      final labels = await labeler.processImage(inputImage);

      setState(() {
        _labels = labels;
        _isProcessing = false;
      });

      await labeler.close();
    } catch (e) {
      debugPrint('Error capturing or processing image: $e');
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Ingredients'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Column(
                    children: [
                      // Camera preview
                      Expanded(
                        flex: 3,
                        child: CameraPreview(_controller!),
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

                      // ML Kit label results
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        )
                      else if (_labels.isNotEmpty)
                        Expanded(
                          flex: 2,
                          child: ListView.builder(
                            itemCount: _labels.length,
                            itemBuilder: (context, index) {
                              final label = _labels[index];
                              return ListTile(
                                title: Text(label.label),
                                subtitle: Text(
                                    'Confidence: ${(label.confidence * 100).toStringAsFixed(1)}%'),
                              );
                            },
                          ),
                        ),

                      // Capture button
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          onPressed: _captureAndDetect,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture & Detect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
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