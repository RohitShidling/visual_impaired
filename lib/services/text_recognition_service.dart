import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class TextRecognitionService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  Future<String> recognizeTextFromImage(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    
    if (recognizedText.text.trim().isEmpty) {
      return 'No text detected in the image.';
    }
    
    // Process the text for better readability
    String processedText = recognizedText.text
        .replaceAll('\n\n', '. ')
        .replaceAll('\n', ' ')
        .replaceAll('  ', ' ')
        .trim();
    
    // Add periods at the end of sentences if missing
    if (!processedText.endsWith('.') && 
        !processedText.endsWith('!') && 
        !processedText.endsWith('?')) {
      processedText += '.';
    }
    
    return processedText;
  }
  
  Future<String> recognizeTextFromCameraImage(CameraImage cameraImage, CameraDescription camera) async {
    // Same issue as in object detection service
    // In a production app, you would convert the CameraImage to InputImage format
    // and process it directly without saving to file
    
    // Placeholder implementation
    return '';
  }
  
  void dispose() {
    _textRecognizer.close();
  }
} 