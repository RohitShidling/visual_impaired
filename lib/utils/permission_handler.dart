import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class AppPermissionHandler {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
  
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  static Future<bool> requestLocationPermission() async {
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
  }
  
  static Future<bool> checkCameraPermission() async {
    return await Permission.camera.isGranted;
  }
  
  static Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }
  
  static Future<bool> checkLocationPermission() async {
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
  }
  
  static Future<bool> requestAllRequiredPermissions() async {
    // Request each permission individually for better control
    final cameraGranted = await requestCameraPermission();
    final microphoneGranted = await requestMicrophonePermission();
    final locationGranted = await requestLocationPermission();
    
    print('Permissions status - Camera: $cameraGranted, Microphone: $microphoneGranted, Location: $locationGranted');
    
    // For the app to function, we need at least camera and microphone
    // Location is important but not critical
    return cameraGranted && microphoneGranted;
  }
} 