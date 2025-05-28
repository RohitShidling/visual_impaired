import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;

import '../models/detected_object.dart';

class ObjectDetectionService {
  late ImageLabeler _imageLabeler;
  bool _isInitialized = false;

  ObjectDetectionService() {
    _initializeLabeler();
  }

  Future<void> _initializeLabeler() async {
    // Initialize the labeler with default settings for higher accuracy
    final ImageLabelerOptions options = ImageLabelerOptions(
      confidenceThreshold: 0.5, // Only return results with 50% confidence or higher
    );
    
    _imageLabeler = ImageLabeler(options: options);
    _isInitialized = true;
    print('Object detection service initialized with Google ML Kit');
  }

  Future<List<VisionDetectedObject>> detectObjectsFromImage(XFile imageFile) async {
    try {
      if (!_isInitialized) {
        await _initializeLabeler();
      }
      
      // Read image file
      final File file = File(imageFile.path);
      final InputImage inputImage = InputImage.fromFile(file);
      
      // Process the image
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      
      // Convert to our model format
      return labels.map((label) => VisionDetectedObject(
        label: label.label,
        confidence: label.confidence,
      )).toList();
    } catch (e) {
      print('Error detecting objects: $e');
      return [];
    }
  }

  Future<List<VisionDetectedObject>> detectObjectsFromCameraImage(CameraImage cameraImage, CameraDescription camera) async {
    try {
      if (!_isInitialized) {
        await _initializeLabeler();
      }
      
      final WriteBuffer allBytes = WriteBuffer();
      
      // Convert camera image to format usable by ML Kit
      for (Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      
      // Get image rotation
      final imageRotation = _getImageRotation(camera.sensorOrientation);
      
      // Create input image
      final InputImage inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: imageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
        ),
      );
      
      // Process the image
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      
      // Convert to our model format
      return labels.map((label) => VisionDetectedObject(
        label: label.label,
        confidence: label.confidence,
      )).toList();
    } catch (e) {
      print('Error detecting objects from camera: $e');
      return [];
    }
  }
  
  InputImageRotation _getImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _imageLabeler.close();
  }
} 