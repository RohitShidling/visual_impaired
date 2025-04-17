import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'dart:async';

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  final StreamController<String> _textStreamController = StreamController<String>.broadcast();
  
  SpeechRecognitionService() {
    _initSpeech();
  }
  
  Stream<String> get textStream => _textStreamController.stream;
  
  Future<void> _initSpeech() async {
    await _speechToText.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );
  }
  
  Future<bool> startListening() async {
    if (!_speechToText.isAvailable) {
      await _initSpeech();
      if (!_speechToText.isAvailable) {
        return false;
      }
    }
    
    if (!_isListening) {
      _isListening = await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        localeId: 'en_US',
      );
    }
    
    return _isListening;
  }
  
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      String text = result.recognizedWords.toLowerCase();
      _textStreamController.add(text);
      _isListening = false;
    }
  }
  
  Future<void> stopListening() async {
    _isListening = false;
    await _speechToText.stop();
  }
  
  bool get isListening => _isListening;
  
  bool get isAvailable => _speechToText.isAvailable;
  
  void dispose() {
    _speechToText.stop();
    _textStreamController.close();
  }
} 