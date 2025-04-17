import 'package:permission_handler/permission_handler.dart';

class AppPermissionHandler {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
  
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  static Future<bool> checkCameraPermission() async {
    return await Permission.camera.isGranted;
  }
  
  static Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }
  
  static Future<bool> requestAllRequiredPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    
    return statuses.values.every((status) => status.isGranted);
  }
} 