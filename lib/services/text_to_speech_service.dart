import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  
  TextToSpeechService() {
    _initTts();
  }
  
  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); // Slightly slower for better comprehension
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }
  
  Future<void> speak(String text) async {
    if (_isSpeaking) {
      await stop();
    }
    
    _isSpeaking = true;
    await _flutterTts.speak(text);
  }
  
  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }
  
  bool get isSpeaking => _isSpeaking;
  
  void dispose() {
    _flutterTts.stop();
  }
} 