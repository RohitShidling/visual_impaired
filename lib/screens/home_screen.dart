import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../constants/app_constants.dart';
import '../services/text_to_speech_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/object_detection_service.dart';
import '../services/text_recognition_service.dart';
import '../services/weather_service.dart';
import '../services/news_service.dart';
import '../utils/permission_handler.dart';
import '../utils/haptic_feedback.dart' as custom_haptic;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // Controllers and services
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  final TextToSpeechService _ttsService = TextToSpeechService();
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final ObjectDetectionService _objectDetectionService = ObjectDetectionService();
  final TextRecognitionService _textRecognitionService = TextRecognitionService();
  final WeatherService _weatherService = WeatherService();
  final NewsService _newsService = NewsService();
  
  // Animation controllers
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  // State variables
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isListening = false;
  bool _isContinuousScanning = false;
  bool _isTorchOn = false;
  int _selectedCameraIndex = 0;
  String _currentMode = 'object'; // Default mode: object, text, scene
  StreamSubscription<String>? _speechSubscription;
  String _feedbackText = AppText.welcomeMessage;
  Timer? _processingTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Setup pulse animation for listening indicator
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseAnimationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseAnimationController.forward();
      }
    });
    
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Request permissions
    final hasPermissions = await AppPermissionHandler.requestAllRequiredPermissions();
    if (!hasPermissions) {
      setState(() {
        _feedbackText = '${AppText.cameraPermissionDenied} ${AppText.microphonePermissionDenied}';
      });
      await _ttsService.speak(_feedbackText);
      return;
    }
    
    // Initialize camera
    try {
      _cameras = await availableCameras();
      
      if (_cameras.isNotEmpty) {
        await _initializeCamera(0);
        
        // Setup speech recognition listener
        _speechSubscription = _speechService.textStream.listen(_handleVoiceCommand);
        
        setState(() {
          _isInitialized = true;
        });
        
        // Welcome message
        await _ttsService.speak(AppText.welcomeMessage);
      } else {
        setState(() {
          _feedbackText = 'No camera found on device.';
        });
        await _ttsService.speak(_feedbackText);
      }
    } catch (e) {
      setState(() {
        _feedbackText = 'Error initializing camera: $e';
      });
      print('Error initializing camera: $e');
    }
  }
  
  Future<void> _initializeCamera(int cameraIndex) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    
    if (_cameras.isEmpty || cameraIndex >= _cameras.length) {
      return;
    }
    
    _cameraController = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    
    try {
      await _cameraController!.initialize();
      
      _selectedCameraIndex = cameraIndex;
      
      // Reset torch status when switching cameras
      _isTorchOn = false;
      
      setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }
  
  void _toggleCameraDirection() async {
    final int newIndex = _selectedCameraIndex == 0 ? 1 : 0;
    if (newIndex < _cameras.length) {
      await _initializeCamera(newIndex);
      await custom_haptic.HapticFeedback.mediumImpact();
    }
  }
  
  void _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      final bool newValue = !_isTorchOn;
      await _cameraController!.setFlashMode(
        newValue ? FlashMode.torch : FlashMode.off,
      );
      setState(() {
        _isTorchOn = newValue;
      });
      await custom_haptic.HapticFeedback.lightImpact();
    } catch (e) {
      print('Error toggling torch: $e');
    }
  }
  
  void _toggleContinuousScanning() async {
    setState(() {
      _isContinuousScanning = !_isContinuousScanning;
    });
    
    if (_isContinuousScanning) {
      await _ttsService.speak('Continuous scanning enabled');
      _startContinuousScanning();
    } else {
      await _ttsService.speak('Continuous scanning disabled');
      _stopContinuousScanning();
    }
    
    await custom_haptic.HapticFeedback.mediumImpact();
  }
  
  void _startContinuousScanning() {
    _processingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isProcessing && _isContinuousScanning) {
        _captureAndProcess();
      }
    });
  }
  
  void _stopContinuousScanning() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }
  
  void _changeMode(String mode) async {
    if (_currentMode != mode) {
      setState(() {
        _currentMode = mode;
      });
      
      String modeText = '';
      switch (mode) {
        case 'object':
          modeText = 'Object detection mode';
          break;
        case 'text':
          modeText = 'Text recognition mode';
          break;
        case 'scene':
          modeText = 'Scene description mode';
          break;
      }
      
      await _ttsService.speak(modeText);
      await custom_haptic.HapticFeedback.lightImpact();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      _stopContinuousScanning();
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_selectedCameraIndex);
      if (_isContinuousScanning) {
        _startContinuousScanning();
      }
    }
  }
  
  Future<void> _captureAndProcess() async {
    await _captureImage();
  }
  
  Future<void> _captureImage() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        XFile image = await _cameraController!.takePicture();
        await _processImage(image);
      }
    } catch (e) {
      print('Error capturing image: $e');
    }
  }
  
  Future<void> _processImage(XFile image) async {
    setState(() {
      _isProcessing = true;
    });
    
    await custom_haptic.HapticFeedback.mediumImpact();
    
    if (!_isContinuousScanning) {
      await _ttsService.speak(AppText.processingMessage);
    }
    
    // Process based on the current mode
    switch (_currentMode) {
      case 'text':
        final detectedText = await _textRecognitionService.recognizeTextFromImage(image);
        if (detectedText.trim().isEmpty) {
          setState(() {
            _feedbackText = 'No text detected.';
          });
          if (!_isContinuousScanning) {
            await _ttsService.speak('No text detected.');
          }
        } else {
          setState(() {
            _feedbackText = detectedText;
          });
          await _ttsService.speak(detectedText);
        }
        break;
        
      case 'object':
        final detectedObjects = await _objectDetectionService.detectObjectsFromImage(image);
        
        if (detectedObjects.isEmpty) {
          setState(() {
            _feedbackText = 'No objects detected.';
          });
          if (!_isContinuousScanning) {
            await _ttsService.speak('No objects detected.');
          }
        } else {
          // Only speak the highest confidence object
          detectedObjects.sort((a, b) => b.confidence.compareTo(a.confidence));
          final highestConfidenceObject = detectedObjects.first;
          
          setState(() {
            _feedbackText = 'Detected: ${highestConfidenceObject.label}';
          });
          await _ttsService.speak(highestConfidenceObject.label);
        }
        break;
        
      case 'scene':
        final detectedObjects = await _objectDetectionService.detectObjectsFromImage(image);
        
        if (detectedObjects.isEmpty) {
          setState(() {
            _feedbackText = 'Could not describe the scene.';
          });
          await _ttsService.speak('Could not describe the scene.');
        } else {
          final StringBuffer result = StringBuffer('I can see ');
          for (int i = 0; i < detectedObjects.length; i++) {
            var object = detectedObjects[i];
            result.write(object.label);
            
            if (i < detectedObjects.length - 2) {
              result.write(', ');
            } else if (i == detectedObjects.length - 2) {
              result.write(' and ');
            }
          }
          
          setState(() {
            _feedbackText = result.toString();
          });
          await _ttsService.speak(result.toString());
        }
        break;
    }
    
    setState(() {
      _isProcessing = false;
    });
  }
  
  Future<void> _toggleListening() async {
    if (_isListening) {
      setState(() {
        _isListening = false;
      });
      _pulseAnimationController.stop();
      await _speechService.stopListening();
      await custom_haptic.HapticFeedback.lightImpact();
    } else {
      await custom_haptic.HapticFeedback.mediumImpact();
      
      setState(() {
        _isListening = true;
        _feedbackText = AppText.listeningMessage;
      });
      
      _pulseAnimationController.forward();
      await _ttsService.speak(AppText.listeningMessage);
      final success = await _speechService.startListening();
      
      if (!success) {
        setState(() {
          _isListening = false;
        });
        _pulseAnimationController.stop();
        _feedbackText = 'Failed to start listening. Please check microphone permissions.';
        await _ttsService.speak('Failed to start listening. Please check microphone permissions.');
      }
    }
  }
  
  Future<void> _handleVoiceCommand(String command) async {
    setState(() {
      _isListening = false;
      _feedbackText = command;
    });
    
    _pulseAnimationController.stop();
    await custom_haptic.HapticFeedback.success();
    
    // Special case for "text reader" command
    if (command.contains('text reader')) {
      _changeMode('text');
      _toggleContinuousScanning();
      setState(() {
        _feedbackText = 'Real-time text reading enabled.';
      });
      await _ttsService.speak('Real-time text reading enabled.');
      return;
    }
    
    // Check if the command is about "real time" or "continuous"
    bool isRealTimeRequest = command.contains('real time') || command.contains('continuous');
    
    // Check for text reading commands
    if (command.contains('read') && command.contains('text')) {
      _changeMode('text');
      
      if (isRealTimeRequest) {
        if (!_isContinuousScanning) {
          _toggleContinuousScanning();
        }
        setState(() {
          _feedbackText = 'Real-time text reading enabled.';
        });
        await _ttsService.speak('Real-time text reading enabled.');
      } else {
        setState(() {
          _feedbackText = 'Reading text. Please hold still.';
        });
        await _ttsService.speak('Reading text. Please hold still.');
        await _captureImage();
      }
    } 
    // Check for object detection commands
    else if (command.contains('detect') && command.contains('object') || 
             command.contains('find') && command.contains('object') ||
             command.contains('what') && command.contains('object')) {
      _changeMode('object');
      
      if (isRealTimeRequest) {
        if (!_isContinuousScanning) {
          _toggleContinuousScanning();
        }
        setState(() {
          _feedbackText = 'Real-time object detection enabled.';
        });
        await _ttsService.speak('Real-time object detection enabled.');
      } else {
        setState(() {
          _feedbackText = 'Detecting objects. Please hold still.';
        });
        await _ttsService.speak('Detecting objects. Please hold still.');
        await _captureImage();
      }
    } 
    // Check for scene description commands
    else if (command.contains('describe') || 
             command.contains('scene') || 
             command.contains('what') && command.contains('see')) {
      _changeMode('scene');
      
      if (isRealTimeRequest) {
        if (!_isContinuousScanning) {
          _toggleContinuousScanning();
        }
        setState(() {
          _feedbackText = 'Real-time scene description enabled.';
        });
        await _ttsService.speak('Real-time scene description enabled.');
      } else {
        setState(() {
          _feedbackText = 'Describing scene. Please hold still.';
        });
        await _ttsService.speak('Describing scene. Please hold still.');
        await _captureImage();
      }
    } 
    // Check for torch/flashlight commands
    else if (command.contains('torch') || 
             command.contains('flashlight') || 
             command.contains('light')) {
      _toggleTorch();
      final status = _isTorchOn ? 'enabled' : 'disabled';
      setState(() {
        _feedbackText = 'Flashlight $status';
      });
      await _ttsService.speak('Flashlight $status');
    } 
    // Check for continuous scanning commands
    else if (command.contains('scan continuously') || 
             command.contains('keep scanning') || 
             command.contains('continuous') || 
             command.contains('real time')) {
      _toggleContinuousScanning();
    } 
    // Check for camera switching commands
    else if (command.contains('switch camera') || 
             command.contains('flip camera') || 
             command.contains('toggle camera') || 
             command.contains('front camera') || 
             command.contains('back camera')) {
      _toggleCameraDirection();
      setState(() {
        _feedbackText = 'Camera switched';
      });
      await _ttsService.speak('Camera switched');
    } 
    // Check for weather commands
    else if (command.contains(AppText.cmdGetWeather)) {
      setState(() {
        _feedbackText = 'Getting weather information...';
      });
      await _ttsService.speak('Getting weather information...');
      
      final weatherSummary = await _weatherService.getCurrentWeatherSummary('London');
      setState(() {
        _feedbackText = weatherSummary;
      });
      await _ttsService.speak(weatherSummary);
    } 
    // Check for news commands
    else if (command.contains(AppText.cmdGetNews)) {
      setState(() {
        _feedbackText = 'Getting the latest news...';
      });
      await _ttsService.speak('Getting the latest news...');
      
      final newsSummary = await _newsService.getTopHeadlinesSummary();
      setState(() {
        _feedbackText = newsSummary;
      });
      await _ttsService.speak(newsSummary);
    } 
    // Check for help commands
    else if (command.contains(AppText.cmdHelp)) {
      setState(() {
        _feedbackText = AppText.helpMessage;
      });
      await _ttsService.speak(AppText.helpMessage);
    } 
    // Check for stop commands
    else if (command.contains(AppText.cmdStop) || 
             command.contains('cancel') || 
             command.contains('quit')) {
      if (_isContinuousScanning) {
        _toggleContinuousScanning();
      }
      setState(() {
        _feedbackText = 'Stopping all actions.';
      });
      await _ttsService.stop();
      await _ttsService.speak('Stopping all actions.');
    } 
    // No recognized command
    else {
      setState(() {
        _feedbackText = AppText.noCommandRecognized;
      });
      await _ttsService.speak(AppText.noCommandRecognized);
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    _objectDetectionService.dispose();
    _textRecognitionService.dispose();
    _speechSubscription?.cancel();
    _processingTimer?.cancel();
    _pulseAnimationController.dispose();
    super.dispose();
  }
  
  Widget _buildModeButton(String mode, IconData icon, String label) {
    final bool isSelected = _currentMode == mode;
    
    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.background : AppColors.onSurface,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.background : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: _cameraController != null && _cameraController!.value.isInitialized
                ? ClipRRect(
                    child: Transform.scale(
                      scale: 1.0,
                      child: AspectRatio(
                        aspectRatio: _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Camera not available',
                      style: TextStyle(color: AppColors.onBackground),
                    ),
                  ),
          ),
          
          // Scanner overlay
          if (!_isProcessing)
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerOverlayPainter(
                  borderColor: _isListening ? AppColors.accent : AppColors.primary,
                  scannerAnimation: _isListening ? _pulseAnimation.value : 1.0,
                ),
              ),
            ),
          
          // Mode selection at the top
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton('object', Icons.remove_red_eye, 'Objects'),
                      const SizedBox(width: 12),
                      _buildModeButton('text', Icons.text_fields, 'Text'),
                      const SizedBox(width: 12),
                      _buildModeButton('scene', Icons.landscape, 'Scene'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Tap anywhere to toggle listening
          Positioned.fill(
            child: GestureDetector(
              onTap: !_isProcessing ? _toggleListening : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          
          // Status overlay at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.secondary.withOpacity(0.9),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _feedbackText,
                    style: const TextStyle(
                      color: AppColors.onSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Torch button
                      FloatingActionButton.small(
                        onPressed: _toggleTorch,
                        backgroundColor: _isTorchOn ? AppColors.accent : AppColors.surface,
                        tooltip: 'Toggle Flashlight',
                        child: Icon(
                          _isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: _isTorchOn ? AppColors.background : AppColors.onSurface,
                        ),
                      ),
                      
                      // Continuous scanning button
                      FloatingActionButton.small(
                        onPressed: _toggleContinuousScanning,
                        backgroundColor: _isContinuousScanning ? AppColors.accent : AppColors.surface,
                        tooltip: 'Continuous Scanning',
                        child: Icon(
                          _isContinuousScanning ? Icons.autorenew : Icons.sync_disabled,
                          color: _isContinuousScanning ? AppColors.background : AppColors.onSurface,
                        ),
                      ),
                      
                      // Microphone button
                      AnimatedBuilder(
                        animation: _pulseAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: FloatingActionButton(
                              onPressed: !_isProcessing ? _toggleListening : null,
                              backgroundColor: _isListening ? AppColors.accent : AppColors.primary,
                              tooltip: 'Voice Command',
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                size: 30,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          );
                        }
                      ),
                      
                      // Capture button
                      FloatingActionButton(
                        onPressed: !_isProcessing && !_isListening ? _captureAndProcess : null,
                        backgroundColor: AppColors.primary,
                        tooltip: 'Capture',
                        child: const Icon(
                          Icons.camera_alt,
                          size: 30,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      
                      // Switch camera button
                      FloatingActionButton.small(
                        onPressed: () => _toggleCameraDirection(),
                        backgroundColor: AppColors.surface,
                        tooltip: 'Switch Camera',
                        child: const Icon(
                          Icons.flip_camera_ios,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Processing indicator
          if (_isProcessing)
            Container(
              color: AppColors.background.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppText.processingMessage,
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double scannerAnimation;
  
  ScannerOverlayPainter({
    required this.borderColor,
    required this.scannerAnimation,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    
    final Paint scanlinePaint = Paint()
      ..color = borderColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final double width = size.width * 0.8;
    final double height = width * 0.75;
    final double left = (size.width - width) / 2;
    final double top = (size.height - height) / 2;
    
    // Draw semi-transparent overlay
    final Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTWH(left, top, width, height))
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(overlayPath, overlayPaint);
    
    // Draw corner borders
    final double cornerSize = 30.0;
    
    // Top-left corner
    canvas.drawLine(
      Offset(left, top + cornerSize),
      Offset(left, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerSize, top),
      borderPaint,
    );
    
    // Top-right corner
    canvas.drawLine(
      Offset(left + width - cornerSize, top),
      Offset(left + width, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + width, top),
      Offset(left + width, top + cornerSize),
      borderPaint,
    );
    
    // Bottom-left corner
    canvas.drawLine(
      Offset(left, top + height - cornerSize),
      Offset(left, top + height),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + cornerSize, top + height),
      borderPaint,
    );
    
    // Bottom-right corner
    canvas.drawLine(
      Offset(left + width - cornerSize, top + height),
      Offset(left + width, top + height),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + width, top + height - cornerSize),
      Offset(left + width, top + height),
      borderPaint,
    );
    
    // Draw scanner animation
    if (scannerAnimation > 1.0) {
      final double scaledWidth = width * scannerAnimation;
      final double scaledHeight = height * scannerAnimation;
      final double scaledLeft = left - ((scaledWidth - width) / 2);
      final double scaledTop = top - ((scaledHeight - height) / 2);
      
      final Rect scannerRect = Rect.fromLTWH(
        scaledLeft,
        scaledTop,
        scaledWidth,
        scaledHeight,
      );
      
      canvas.drawRect(scannerRect, scanlinePaint);
    }
  }
  
  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor || 
           oldDelegate.scannerAnimation != scannerAnimation;
  }
} 