import 'package:vibration/vibration.dart';

class HapticFeedback {
  static Future<void> lightImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
  }
  
  static Future<void> mediumImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }
  
  static Future<void> heavyImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 300);
    }
  }
  
  static Future<void> success() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 50, 100, 50]);
    }
  }
  
  static Future<void> error() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 100, 100, 100, 100, 100]);
    }
  }
  
  static Future<void> warning() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 100, 100, 100]);
    }
  }
} 