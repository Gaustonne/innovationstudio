import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;

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
          setState(() {
            _predictedLabel = topPrediction['tagName'];
            _confidence = topPrediction['probability'];
          });
        }
      } else {
        debugPrint('Prediction API error: ${response.statusCode} ${response.body}');
      }

      setState(() => _isProcessing = false);
    } catch (e) {
      debugPrint('Error capturing or predicting image: $e');
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
                        child: ElevatedButton.icon(
                          onPressed: _captureAndPredict,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture & Predict'),
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