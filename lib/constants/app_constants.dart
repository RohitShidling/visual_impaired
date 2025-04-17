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
  static const String cmdGetWeather = 'weather';
  static const String cmdGetNews = 'news';
  static const String cmdHelp = 'help';
  static const String cmdStop = 'stop';
  
  // Voice Responses
  static const String welcomeMessage = 'Welcome to Vision Assist. Tap anywhere on the screen to start listening for commands.';
  static const String listeningMessage = 'Listening...';
  static const String processingMessage = 'Processing...';
  static const String noCommandRecognized = 'Sorry, I didn\'t recognize your command. Try again.';
  static const String helpMessage = 'Available commands: Read text, Detect objects, Describe scene, Flashlight, Switch camera, Scan continuously, Weather, News, Help, and Stop.';
  
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
  static const double minimumConfidenceScore = 0.6;
  static const int speechListeningTimeout = 5000; // milliseconds
  static const int vibrationDuration = 300; // milliseconds
  static const int continuousScanningInterval = 3000; // milliseconds
} 