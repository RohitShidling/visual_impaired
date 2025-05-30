import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class AppPermissionHandler {
  // Track permission states
  static bool _isCameraPermissionRequested = false;
  static bool _isMicrophonePermissionRequested = false;
  static bool _isStoragePermissionRequested = false;
  
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
  
  static Future<bool> requestStoragePermission() async {
    try {
      Permission storagePermission;
      
      // Use the appropriate permission based on Android version
      if (Platform.isAndroid) {
        // For Android, we need to use the appropriate permission
        // based on the Android version
        if (await _isAndroid13OrHigher()) {
          // Use Photos and Media permission for Android 13+
          storagePermission = Permission.photos;
        } else {
          // Use storage for older versions
          storagePermission = Permission.storage;
        }
      } else {
        // For iOS and other platforms
        storagePermission = Permission.storage;
      }
      
      final status = await storagePermission.status;
      
      // If permission is already granted, return true
      if (status.isGranted) {
        return true;
      }
      
      // If it's permanently denied, we need to open app settings
      if (status.isPermanentlyDenied) {
        return false;
      }
      
      // Request permission
      _isStoragePermissionRequested = true;
      final result = await storagePermission.request();
      return result.isGranted;
    } catch (e) {
      print('Error requesting storage permission: $e');
      return false;
    }
  }
  
  static Future<bool> _isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 33; // Android 13 is API 33
    }
    return false;
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
  
  static Future<bool> checkStoragePermission() async {
    try {
      Permission storagePermission;
      
      if (Platform.isAndroid) {
        if (await _isAndroid13OrHigher()) {
          storagePermission = Permission.photos;
        } else {
          storagePermission = Permission.storage;
        }
      } else {
        storagePermission = Permission.storage;
      }
      
      return await storagePermission.isGranted;
    } catch (e) {
      print('Error checking storage permission: $e');
      return false;
    }
  }
  
  static Future<Map<String, bool>> requestAllRequiredPermissions() async {
    // Request each permission individually for better control
    final cameraGranted = await requestCameraPermission();
    final microphoneGranted = await requestMicrophonePermission();
    final locationGranted = await requestLocationPermission();
    final storageGranted = await requestStoragePermission();
    
    final results = {
      'camera': cameraGranted,
      'microphone': microphoneGranted,
      'location': locationGranted,
      'storage': storageGranted,
    };
    
    print('Permissions status - Camera: $cameraGranted, Microphone: $microphoneGranted, Location: $locationGranted, Storage: $storageGranted');
    
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
    
    if (_isStoragePermissionRequested) {
      if (Platform.isAndroid) {
        if (await _isAndroid13OrHigher()) {
          if (await Permission.photos.isPermanentlyDenied) {
            return true;
          }
        } else if (await Permission.storage.isPermanentlyDenied) {
          return true;
        }
      } else if (await Permission.storage.isPermanentlyDenied) {
        return true;
      }
    }
    
    return false;
  }
  
  // Open app settings so the user can enable permissions
  static Future<bool> openSettings() async {
    // Use the top-level openAppSettings function
    return await openAppSettings();
  }
} 