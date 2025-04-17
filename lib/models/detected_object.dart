class VisionDetectedObject {
  final String label;
  final double confidence;
  final double? x;
  final double? y;
  final double? width;
  final double? height;
  
  VisionDetectedObject({
    required this.label,
    required this.confidence,
    this.x,
    this.y,
    this.width,
    this.height,
  });
  
  @override
  String toString() {
    return '$label with ${(confidence * 100).toStringAsFixed(0)}% confidence';
  }
} 