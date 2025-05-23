import 'package:flutter/material.dart';

// App Text Constants
class AppText {
  // App Name
  static const String appName = 'Vision Assist';
  
  // Voice Commands
  static const String cmdReadText = 'read text';
  static const String cmdDetectObjects = 'detect objects';
  static const String cmdDescribeScene = 'describe scene';
  static const String cmdToggleFlashlight = 'flashlight';
  static const String cmdSwitchCamera = 'switch camera';
  static const String cmdScanContinuously = 'scan continuously';
  static const String cmdRealTime = 'real time';
  static const String cmdCapture = 'capture';
  static const String cmdObjectMode = 'object mode';
  static const String cmdTextMode = 'text mode';
  static const String cmdSceneMode = 'scene mode';
  static const String cmdGetWeather = 'weather';
  static const String cmdGetNews = 'news';
  
  // News-specific commands
  static const String cmdNewsFromLocation = 'news from';
  static const String cmdNewsCategory = 'news';
  static const String cmdTellMeNews = 'tell me the news';
  static const String cmdWhatsHappening = 'what\'s happening';
  
  static const String cmdHelp = 'help';
  static const String cmdStop = 'stop';
  
  // Voice Responses
  static const String welcomeMessage = 'Welcome to Vision Assist. Tap anywhere on the screen to start listening for commands, or use the top buttons to switch modes.';
  static const String listeningMessage = 'Listening...';
  static const String processingMessage = 'Processing...';
  static const String noCommandRecognized = 'Sorry, I didn\'t recognize your command. Try again or say "help" for available commands.';
  static const String helpMessage = 'Available commands: Object mode, Text mode, Scene mode, Read text, Detect objects, Describe scene, Capture, Flashlight, Switch camera, Real time scanning, Weather, News, Help, and Stop. For news, you can say "Tell me the news", "Business news", "Sports news from India" or "News from Hubli".';
  
  // Instructions
  static const String cameraPermissionDenied = 'Camera permission is required to use this app.';
  static const String microphonePermissionDenied = 'Microphone permission is required to use this app.';
}

// App Color Constants
class AppColors {
  static const Color primary = Color(0xFF4A6572);
  static const Color secondary = Color(0xFF344955);
  static const Color accent = Color(0xFFF9AA33);
  static const Color background = Color(0xFF232F34);
  static const Color surface = Color(0xFF4A6572);
  static const Color error = Color(0xFFB00020);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onError = Color(0xFFFFFFFF);
}

// Feature Constants
class FeatureConstants {
  static const double minimumConfidenceScore = 0.7;
  static const int speechListeningTimeout = 10000;
  static const int vibrationDuration = 300;
  static const int continuousScanningInterval = 3000;
} 