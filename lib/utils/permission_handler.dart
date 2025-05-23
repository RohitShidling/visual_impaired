import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class AppPermissionHandler {
  // Track permission states
  static bool _isCameraPermissionRequested = false;
  static bool _isMicrophonePermissionRequested = false;
  
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      
      // If permission is already granted, return true
      if (status.isGranted) {
        return true;
      }
      
      // If it's permanently denied, we need to open app settings
      if (status.isPermanentlyDenied) {
        return false;
      }
      
      // Request permission
      _isCameraPermissionRequested = true;
      final result = await Permission.camera.request();
      return result.isGranted;
    } catch (e) {
      print('Error requesting camera permission: $e');
      return false;
    }
  }
  
  static Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      
      // If permission is already granted, return true
      if (status.isGranted) {
        return true;
      }
      
      // If it's permanently denied, we need to open app settings
      if (status.isPermanentlyDenied) {
        return false;
      }
      
      // Request permission
      _isMicrophonePermissionRequested = true;
      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }
  
  static Future<bool> requestLocationPermission() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, try to request
        print('Location services are not enabled');
        return false;
      }
      
      // Request permission through permission_handler
      final permissionStatus = await Permission.location.request();
      if (permissionStatus.isGranted) {
        return true;
      }
      
      // If permission_handler didn't work, try with Geolocator directly
      LocationPermission geoPermission = await Geolocator.checkPermission();
      if (geoPermission == LocationPermission.denied) {
        geoPermission = await Geolocator.requestPermission();
      }
      
      return geoPermission == LocationPermission.always || 
             geoPermission == LocationPermission.whileInUse;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }
  
  static Future<bool> checkCameraPermission() async {
    try {
      return await Permission.camera.isGranted;
    } catch (e) {
      print('Error checking camera permission: $e');
      return false;
    }
  }
  
  static Future<bool> checkMicrophonePermission() async {
    try {
      return await Permission.microphone.isGranted;
    } catch (e) {
      print('Error checking microphone permission: $e');
      return false;
    }
  }
  
  static Future<bool> checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      
      final permissionStatus = await Permission.location.status;
      if (permissionStatus.isGranted) {
        return true;
      }
      
      LocationPermission geoPermission = await Geolocator.checkPermission();
      return geoPermission == LocationPermission.always || 
             geoPermission == LocationPermission.whileInUse;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }
  
  static Future<Map<String, bool>> requestAllRequiredPermissions() async {
    // Request each permission individually for better control
    final cameraGranted = await requestCameraPermission();
    final microphoneGranted = await requestMicrophonePermission();
    final locationGranted = await requestLocationPermission();
    
    final results = {
      'camera': cameraGranted,
      'microphone': microphoneGranted,
      'location': locationGranted,
    };
    
    print('Permissions status - Camera: $cameraGranted, Microphone: $microphoneGranted, Location: $locationGranted');
    
    return results;
  }
  
  // Check if we need to show a settings popup based on denied permissions
  static Future<bool> shouldShowPermissionSettingsPrompt() async {
    // Check if camera or microphone has been requested but is now permanently denied
    if (_isCameraPermissionRequested && await Permission.camera.isPermanentlyDenied) {
      return true;
    }
    
    if (_isMicrophonePermissionRequested && await Permission.microphone.isPermanentlyDenied) {
      return true;
    }
    
    return false;
  }
  
  // Open app settings so the user can enable permissions
  static Future<bool> openSettings() async {
    // Use the top-level openAppSettings function
    return await openAppSettings();
  }
} 