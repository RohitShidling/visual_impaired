import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'dart:async';
import '../utils/permission_handler.dart';

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  final StreamController<String> _textStreamController = StreamController<String>.broadcast();
  
  SpeechRecognitionService() {
    _initSpeech();
  }
  
  Stream<String> get textStream => _textStreamController.stream;
  
  Future<void> _initSpeech() async {
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) => _handleSpeechError(error.errorMsg),
        onStatus: (status) => print('Speech recognition status: $status'),
      );
      print('Speech recognition initialized: $_isInitialized');
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      _isInitialized = false;
    }
  }
  
  void _handleSpeechError(String errorMsg) {
    print('Speech recognition error: $errorMsg');
    
    // If it's a permission error, we need to request it again
    if (errorMsg.toLowerCase().contains('permission') ||
        errorMsg.toLowerCase().contains('microphone')) {
      // Reset the initialized flag so we try to initialize again next time
      _isInitialized = false;
    }
  }
  
  Future<bool> startListening() async {
    // Check if we're already initialized
    if (_isInitialized) {
      // If already initialized, just try to start listening
      try {
        // Make sure we're not already listening
        if (_isListening) {
          await _speechToText.stop();
        }
        
        // Small delay to ensure the speech recognizer is ready
        await Future.delayed(const Duration(milliseconds: 100));
        
        _isListening = await _speechToText.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          localeId: 'en_US',
          listenMode: ListenMode.confirmation,
        ) ?? false;  // Handle null safely
        
        print('Started listening: $_isListening');
        return _isListening;
      } catch (e) {
        print('Speech recognition listen error: $e');
        _isListening = false;
        return false;
      }
    }
    
    // If not initialized, try to initialize
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) => _handleSpeechError(error.errorMsg),
        onStatus: (status) => print('Speech recognition status: $status'),
      );
      
      if (!_isInitialized) {
        print('Failed to initialize speech recognition');
        return false;
      }
      
      // Now try to start listening
      _isListening = await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
        listenMode: ListenMode.confirmation,
      ) ?? false;
      
      print('Started listening after initialization: $_isListening');
      return _isListening;
    } catch (e) {
      print('Error initializing/starting speech recognition: $e');
      _isInitialized = false;
      _isListening = false;
      return false;
    }
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
  
  Future<void> cancelListening() async {
    _isListening = false;
    await _speechToText.cancel();
  }
  
  Future<void> resetListening() async {
    await stopListening();
    _isInitialized = false;
    await _initSpeech();
  }
  
  bool get isListening => _isListening;
  
  bool get isAvailable => _isInitialized;
  
  void dispose() {
    _speechToText.stop();
    _textStreamController.close();
  }
} 