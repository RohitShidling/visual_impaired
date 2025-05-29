import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class WakeWordService {
  static const String _prefKeyPicovoiceApiKey = 'picovoice_api_key';
  
  PorcupineManager? _porcupineManager;
  bool _isListening = false;
  bool _isPaused = false;
  final StreamController<bool> _wakeWordDetectedController = StreamController<bool>.broadcast();
  String _apiKey = FeatureConstants.defaultPicovoiceApiKey;
  late String _keywordPath;
  
  // Public stream to listen for wake word detection events
  Stream<bool> get wakeWordDetected => _wakeWordDetectedController.stream;
  
  // Initialize the wake word service
  Future<bool> initialize() async {
    try {
      // Load API key from preferences, use default if not found
      await _loadApiKey();
      
      // Copy wake word model from assets to local directory
      _keywordPath = await _getKeywordPath();
      
      return true;
    } catch (e) {
      print('Error initializing wake word service: $e');
      return false;
    }
  }
  
  // Load API key from shared preferences
  Future<void> _loadApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKey = prefs.getString(_prefKeyPicovoiceApiKey);
      
      if (storedKey != null && storedKey.isNotEmpty) {
        _apiKey = storedKey;
      } else {
        _apiKey = FeatureConstants.defaultPicovoiceApiKey;
      }
    } catch (e) {
      print('Error loading Picovoice API key: $e');
      _apiKey = FeatureConstants.defaultPicovoiceApiKey;
    }
  }
  
  // Save new API key to shared preferences
  Future<void> saveApiKey(String newApiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyPicovoiceApiKey, newApiKey);
      
      // Update current API key
      _apiKey = newApiKey;
      
      // Restart service with new API key if currently running
      if (_isListening) {
        await stop();
        await start();
      }
    } catch (e) {
      print('Error saving Picovoice API key: $e');
      throw Exception('Failed to save API key: $e');
    }
  }
  
  // Copy wake word model from assets to local directory
  Future<String> _getKeywordPath() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String keywordPath = '${appDir.path}/app_flutter/${FeatureConstants.wakeWordModelFile}';
    final File keywordFile = File(keywordPath);
    
    // Ensure directory exists
    final Directory dir = Directory('${appDir.path}/app_flutter');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    // Check if file already exists
    if (!await keywordFile.exists()) {
      // Copy from assets
      final ByteData data = await rootBundle.load('assets/wakeword/${FeatureConstants.wakeWordModelFile}');
      final List<int> bytes = data.buffer.asUint8List();
      await keywordFile.writeAsBytes(bytes);
    }
    
    return keywordPath;
  }
  
  // Start wake word detection
  Future<bool> start() async {
    if (_isPaused) {
      // If we're paused, just resume
      return await resume();
    }
    
    try {
      // Make sure we're initialized first
      if (_porcupineManager == null) {
        final bool initialized = await initialize();
        if (!initialized) {
          return false;
        }
        
        // Create the wake word manager
        _porcupineManager = await PorcupineManager.fromKeywordPaths(
          _apiKey,
          [_keywordPath],
          _onWakeWordDetected,
          sensitivities: [0.5],
          errorCallback: (error) {
            print('Wake word detection error: ${error.message}');
          },
        );
      }
      
      // Start listening
      await _porcupineManager?.start();
      _isListening = true;
      _isPaused = false;
      return true;
    } catch (e) {
      print('Error starting wake word detection: $e');
      return false;
    }
  }
  
  // Stop listening for wake word
  Future<void> stop() async {
    if (_isListening) {
      try {
        await _porcupineManager?.stop();
        _isListening = false;
        _isPaused = false;
      } catch (e) {
        print('Error stopping wake word detection: $e');
      }
    }
  }
  
  // Pause wake word detection (temporarily)
  void pause() {
    if (_isListening && !_isPaused) {
      try {
        _porcupineManager?.stop();
        _isPaused = true;
        print('Wake word detection paused');
      } catch (e) {
        print('Error pausing wake word detection: $e');
      }
    }
  }
  
  // Resume wake word detection after pause
  Future<bool> resume() async {
    if (_isPaused) {
      try {
        // Small delay to ensure microphone resources are released
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Start listening again
        await _porcupineManager?.start();
        _isListening = true;
        _isPaused = false;
        print('Wake word detection resumed');
        return true;
      } catch (e) {
        print('Error resuming wake word detection: $e');
        
        // Try recreating the manager
        try {
          await _porcupineManager?.delete();
          _porcupineManager = null;
          
          _porcupineManager = await PorcupineManager.fromKeywordPaths(
            _apiKey,
            [_keywordPath],
            _onWakeWordDetected,
            sensitivities: [0.5],
            errorCallback: (error) {
              print('Wake word detection error: ${error.message}');
            },
          );
          
          await _porcupineManager?.start();
          _isListening = true;
          _isPaused = false;
          print('Wake word detection resumed after recreation');
          return true;
        } catch (e2) {
          print('Error recreating wake word detection: $e2');
          return false;
        }
      }
    }
    return _isListening;
  }
  
  // Callback when wake word is detected
  void _onWakeWordDetected(int keywordIndex) {
    if (!_isPaused) {
      print('Wake word detected: ${FeatureConstants.wakeWordName}');
      _wakeWordDetectedController.add(true);
    }
  }
  
  // Check if currently listening
  bool get isListening => _isListening && !_isPaused;
  
  // Clean up resources
  void dispose() {
    _porcupineManager?.delete();
    _wakeWordDetectedController.close();
  }
} 