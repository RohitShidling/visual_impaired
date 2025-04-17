import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detected_object.dart';

class ObjectDetectionService {
  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.6),
  );
  
  Future<List<VisionDetectedObject>> detectObjectsFromImage(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
    
    return labels.map((label) => VisionDetectedObject(
      label: label.label,
      confidence: label.confidence,
    )).toList();
  }
  
  Future<List<VisionDetectedObject>> detectObjectsFromCameraImage(CameraImage cameraImage, CameraDescription camera) async {
    // In a real app, you would use tflite_flutter to process the image directly
    // For simplicity, this example extracts a still image from the camera feed
    // and processes it using the same method as above
    
    // This is a simplified placeholder
    // In a real implementation, you would:
    // 1. Convert the CameraImage to an InputImage format
    // 2. Use TFLite or ML Kit to process directly without saving to file
    
    // Placeholder implementation
    return [];
  }
  
  void dispose() {
    _imageLabeler.close();
  }
} 