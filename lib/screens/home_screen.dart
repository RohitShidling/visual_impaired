import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:math' as Math;

import '../constants/app_constants.dart';
import '../services/text_to_speech_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/object_detection_service.dart';
import '../services/text_recognition_service.dart';
import '../services/weather_service.dart';
import '../services/news_service.dart';
import '../utils/permission_handler.dart';
import '../utils/haptic_feedback.dart' as custom_haptic;
import '../widgets/api_settings_dialog.dart';

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
  bool _isRealTimeDetection = false;
  int _selectedCameraIndex = 0;
  String _currentMode = 'object'; // Default mode: object, text, scene
  StreamSubscription<String>? _speechSubscription;
  String _feedbackText = AppText.welcomeMessage;
  Timer? _processingTimer;
  Timer? _realTimeDetectionTimer;
  String _lastDetectedObject = '';
  DateTime _lastDetectionTime = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Setup pulse animation for listening indicator
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Create a repeating pulse effect that's subtle but noticeable
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    
    // Make the animation repeat
    _pulseAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseAnimationController.repeat(reverse: true);
      }
    });
    
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Request permissions
    final permissionsResult = await AppPermissionHandler.requestAllRequiredPermissions();
    final bool cameraGranted = permissionsResult['camera'] ?? false;
    final bool microphoneGranted = permissionsResult['microphone'] ?? false;
    
    // Check if permissions were denied - show appropriate messages
    if (!cameraGranted || !microphoneGranted) {
      String permissionMessages = '';
      
      if (!cameraGranted) {
        permissionMessages += AppText.cameraPermissionDenied;
      }
      
      if (!microphoneGranted) {
        if (permissionMessages.isNotEmpty) {
          permissionMessages += ' ';
        }
        permissionMessages += AppText.microphonePermissionDenied;
      }
      
      setState(() {
        _feedbackText = permissionMessages;
      });
      
      await _ttsService.speak(permissionMessages);
      
      // Check if we should show settings dialog
      final shouldShowSettings = await AppPermissionHandler.shouldShowPermissionSettingsPrompt();
      if (shouldShowSettings) {
        // Delay a bit to allow TTS to complete
        await Future.delayed(const Duration(milliseconds: 500));
        _showPermissionSettingsDialog();
      }
      
      // If either camera or mic is not granted, we can't proceed with full functionality
      if (!cameraGranted) {
        return; // Can't continue without camera
      }
    }
    
    // Initialize camera
    try {
      _cameras = await availableCameras();
      
      if (_cameras.isNotEmpty) {
        await _initializeCamera(0);
        
        // Only set up speech recognition if microphone permission is granted
        if (microphoneGranted) {
          _speechSubscription = _speechService.textStream.listen(_handleVoiceCommand);
        }
        
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
      
      // Start image stream if real-time detection is enabled
      if (_isRealTimeDetection) {
        _startRealTimeDetection();
      }
      
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
  
  void _toggleRealTimeDetection() async {
    setState(() {
      _isRealTimeDetection = !_isRealTimeDetection;
    });
    
    if (_isRealTimeDetection) {
      await _ttsService.speak('Real-time detection enabled');
      _startRealTimeDetection();
    } else {
      await _ttsService.speak('Real-time detection disabled');
      _stopRealTimeDetection();
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
  
  void _startRealTimeDetection() {
    if (_cameraController != null && 
        _cameraController!.value.isInitialized && 
        !_cameraController!.value.isStreamingImages) {
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isProcessing) {
          _processRealTimeFrame(image);
        }
      });
    }
    
    // Timer to limit speech feedback frequency
    _realTimeDetectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Just to keep the timer active
    });
  }
  
  void _stopRealTimeDetection() {
    if (_cameraController != null && 
        _cameraController!.value.isInitialized && 
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    
    _realTimeDetectionTimer?.cancel();
    _realTimeDetectionTimer = null;
  }
  
  Future<void> _processRealTimeFrame(CameraImage image) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final objects = await _objectDetectionService.detectObjectsFromCameraImage(
        image, 
        _cameras[_selectedCameraIndex]
      );
      
      if (objects.isNotEmpty) {
        // Sort by confidence and get the highest confidence object
        objects.sort((a, b) => b.confidence.compareTo(a.confidence));
        final highestConfidenceObject = objects.first;
        
        // Only update the UI and speak if it's a different object or if enough time has passed
        final now = DateTime.now();
        if (highestConfidenceObject.label != _lastDetectedObject || 
            now.difference(_lastDetectionTime).inSeconds > 3) {
          
          setState(() {
            _feedbackText = 'I see a ${highestConfidenceObject.label}';
            _lastDetectedObject = highestConfidenceObject.label;
            _lastDetectionTime = now;
          });
          
          await _ttsService.speak('I see a ${highestConfidenceObject.label}');
        }
      }
    } catch (e) {
      print('Error in real-time detection: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  void _changeMode(String mode) async {
    if (_currentMode != mode) {
      setState(() {
        _currentMode = mode;
      });
      
      String modeText = '';
      bool shouldCaptureImage = false;
      
      switch (mode) {
        case 'object':
          modeText = 'Object detection mode activated.';
          shouldCaptureImage = true;
          break;
        case 'text':
          modeText = 'Text recognition mode activated.';
          shouldCaptureImage = true;
          break;
        case 'scene':
          modeText = 'Scene description mode activated.';
          shouldCaptureImage = true;
          break;
      }
      
      setState(() {
        _feedbackText = modeText;
      });
      
      await _ttsService.speak(modeText);
      await custom_haptic.HapticFeedback.lightImpact();
      
      // Automatically capture an image when mode is changed manually
      if (shouldCaptureImage && !_isContinuousScanning) {
        // Slight delay to allow the UI to update and TTS to start
        await Future.delayed(const Duration(milliseconds: 500));
        await _captureImage();
      }
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
      _stopRealTimeDetection();
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_selectedCameraIndex);
      if (_isContinuousScanning) {
        _startContinuousScanning();
      }
      if (_isRealTimeDetection) {
        _startRealTimeDetection();
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
            _feedbackText = 'I see a ${highestConfidenceObject.label}';
          });
          await _ttsService.speak('I see a ${highestConfidenceObject.label}');
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
      // First check microphone permission without showing UI feedback
      final micPermission = await AppPermissionHandler.checkMicrophonePermission();
      if (!micPermission) {
        // Only set feedback text if permission is denied
        setState(() {
          _feedbackText = 'Microphone permission is required.';
        });
        
        // Request microphone permission silently
        final granted = await AppPermissionHandler.requestMicrophonePermission();
        if (!granted) {
          // Show settings dialog immediately
          _showPermissionSettingsDialog();
          return;
        } else {
          // Permission was just granted, delay a bit to let the system register it
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      await custom_haptic.HapticFeedback.mediumImpact();
      
      // Attempt to initialize speech recognition service if needed
      if (!_speechService.isAvailable) {
        await _speechService.resetListening();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      setState(() {
        _isListening = true;
        _feedbackText = AppText.listeningMessage;
      });
      
      // Start the animation controller
      _pulseAnimationController.reset();
      _pulseAnimationController.forward();
      
      await _ttsService.speak(AppText.listeningMessage);
      
      // Small delay to ensure TTS finishes before starting listening
      await Future.delayed(const Duration(milliseconds: 300));
      
      final success = await _speechService.startListening();
      
      if (!success) {
        setState(() {
          _isListening = false;
          _feedbackText = 'Failed to start listening.';
        });
        _pulseAnimationController.stop();
        
        // Try requesting permission again without speaking
        final hasPermission = await AppPermissionHandler.requestMicrophonePermission();
        if (!hasPermission) {
          // Show dialog without speaking
          _showPermissionSettingsDialog();
        } else {
          // Show a retry button or message
          setState(() {
            _feedbackText = 'Tap microphone to try again.';
          });
        }
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
    
    // Direct mode commands
    if (command.contains('object mode') || command.contains('objects mode') || command == 'object' || command == 'objects') {
      _changeMode('object');
      return;
    }
    
    if (command.contains('text mode') || command == 'text') {
      _changeMode('text');
      return;
    }
    
    if (command.contains('scene mode') || command == 'scene') {
      _changeMode('scene');
      return;
    }
    
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
    // Check for capture/take picture commands
    else if (command.contains('capture') || 
             command.contains('take picture') || 
             command.contains('take photo') || 
             command.contains('take image')) {
      setState(() {
        _feedbackText = 'Capturing image. Please hold still.';
      });
      await _ttsService.speak('Capturing image. Please hold still.');
      await _captureImage();
    }
    // Check for weather commands
    else if (command.contains(AppText.cmdGetWeather)) {
      setState(() {
        _feedbackText = 'Getting weather information...';
      });
      
      // Check if a specific city was mentioned
      final RegExp cityRegex = RegExp(r'weather\s+(?:in|for|at)?\s+([a-zA-Z\s]+)', caseSensitive: false);
      final match = cityRegex.firstMatch(command);
      
      String weatherSummary;
      if (match != null && match.group(1) != null) {
        final city = match.group(1)!.trim();
        await _ttsService.speak('Getting weather information for $city...');
        weatherSummary = await _weatherService.getWeatherForCity(city);
      } else {
        await _ttsService.speak('Getting weather information...');
        weatherSummary = await _weatherService.getCurrentWeatherSummary();
      }
      
      setState(() {
        _feedbackText = weatherSummary;
      });
      await _ttsService.speak(weatherSummary);
    } 
    // Check for news commands
    else if (command.contains(AppText.cmdGetNews) || 
             _isNewsCommand(command)) {
      setState(() {
        _feedbackText = 'Getting the latest news...';
      });
      await _ttsService.speak('Getting the latest news...');
      
      // Get formatted display text
      final newsSummary = await _newsService.getNewsForSpeech(command);
      
      // Get speech-friendly version for speaking
      final speechOutput = await _newsService.getNewsForSpeechOutput(command);
      
      setState(() {
        _feedbackText = newsSummary;
      });
      
      // Speak the speech-friendly version
      await _ttsService.speak(speechOutput);
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
    _realTimeDetectionTimer?.cancel();
    _pulseAnimationController.dispose();
    super.dispose();
  }
  
  Widget _buildModeButton(String mode, IconData icon, String label) {
    final bool isSelected = _currentMode == mode;
    
    return ElevatedButton(
      onPressed: () => _changeMode(mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.accent : AppColors.surface,
        foregroundColor: isSelected ? AppColors.background : AppColors.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: isSelected ? 4 : 2,
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
          
          // Touch area for voice listening - covers most of the screen
          Positioned.fill(
            child: GestureDetector(
              onTap: !_isProcessing ? _toggleListening : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          
          // Mode selection at the top
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Material(
              color: AppColors.background.withOpacity(0.7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildModeButton('object', Icons.remove_red_eye, 'Objects'),
                              const SizedBox(width: 16),
                              _buildModeButton('text', Icons.text_fields, 'Text'),
                              const SizedBox(width: 16),
                              _buildModeButton('scene', Icons.landscape, 'Scene'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Add three-dot menu
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.onSecondary,
                      ),
                      onSelected: (String value) {
                        _showApiSettingsDialog(value);
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'news',
                          child: Text('News API Settings'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'weather',
                          child: Text('Weather API Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  _buildFeedbackView(),
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
                      
                      // Microphone button with professional animation
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Listening indicator text
                          if (_isListening)
                            Positioned(
                              bottom: -32,
                              child: AnimatedOpacity(
                                opacity: _isListening ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Listening...',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Microphone button with animation
                          AnimatedBuilder(
                            animation: _pulseAnimationController,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Ripple effect when listening - more subtle
                                  if (_isListening)
                                    ...List.generate(2, (index) {
                                      return Positioned.fill(
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.accent.withOpacity(
                                                index == 0 
                                                  ? 0.4 - (0.3 * _pulseAnimation.value)
                                                  : 0.2 - (0.15 * (1 - _pulseAnimation.value))
                                              ),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  
                                  // Sound wave visualization - cleaner design
                                  if (_isListening)
                                    Positioned(
                                      bottom: -5,
                                      child: Container(
                                        width: 36,
                                        height: 12,
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: List.generate(4, (index) {
                                            // Create animated sound wave bars with smoother animation
                                            final double delayedValue = ((_pulseAnimation.value + (index * 0.2)) % 1.0);
                                            // Sine wave pattern for more natural movement
                                            final double multiplier = 0.5 + (0.5 * Math.sin(delayedValue * Math.pi));
                                            final double height = 3.0 + (6.0 * multiplier);
                                            
                                            return Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                              width: 2,
                                              height: height,
                                              decoration: BoxDecoration(
                                                color: AppColors.accent.withOpacity(0.7 + (0.3 * multiplier)),
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                  
                                  // The main button - with light glow when active
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: _isListening ? [
                                        BoxShadow(
                                          color: AppColors.accent.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ] : [],
                                    ),
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
                                  ),
                                ],
                              );
                            }
                          ),
                        ],
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

  void _showApiSettingsDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => ApiSettingsDialog(initialType: type),
    );
  }

  // Helper method to detect news-related commands
  bool _isNewsCommand(String command) {
    final String normalizedCommand = command.toLowerCase().trim();
    
    // Direct city name check - if it's just a city name, treat it as a news query
    final List<String> commonCities = [
      'delhi', 'mumbai', 'bangalore', 'bengaluru', 'chennai', 'kolkata',
      'hyderabad', 'pune', 'ahmedabad', 'surat', 'hubli', 'hubballi', 'dharwad',
      'jaipur', 'lucknow', 'kanpur', 'nagpur', 'indore', 'thane'
    ];
    
    // Check if the command is just a city name
    for (final city in commonCities) {
      if (normalizedCommand == city || normalizedCommand == '$city news') {
        return true;
      }
    }
    
    // General news inquiry patterns
    final List<String> generalNewsPatterns = [
      'tell me', 'show me', 'get me', 'read me', 'give me', 'find',
      'latest', 'current', 'recent', 'today', 'top', 'breaking',
      'what\'s happening', 'what is happening', 'what\'s going on'
    ];
    
    // If the command contains "news" and any of the general inquiry patterns
    for (final pattern in generalNewsPatterns) {
      if (normalizedCommand.contains(pattern) && normalizedCommand.contains('news')) {
        return true;
      }
    }
    
    // Check for direct inquiry phrases that don't necessarily include "news"
    if (normalizedCommand.contains('what\'s happening') || 
        normalizedCommand.contains('what is happening') ||
        normalizedCommand.contains('what\'s going on') ||
        normalizedCommand.contains('what is going on') ||
        normalizedCommand.contains('current events') ||
        normalizedCommand.contains('headlines') ||
        (normalizedCommand.contains('updates') && !normalizedCommand.contains('weather'))) {
      return true;
    }
    
    // Check for queries with just the word "news"
    if (normalizedCommand == 'news' || 
        normalizedCommand.startsWith('news ') || 
        normalizedCommand.endsWith(' news') ||
        normalizedCommand.contains(' news ')) {
      return true;
    }
    
    // Check for news category patterns
    final List<String> newsCategories = [
      'business', 'sports', 'technology', 'health', 'science', 
      'entertainment', 'general', 'political', 'politics', 
      'financial', 'economy', 'tech', 'sport'
    ];
    
    for (final category in newsCategories) {
      // Look for "<category> news" or "news about <category>"
      if ((normalizedCommand.contains(category) && normalizedCommand.contains('news')) ||
          (normalizedCommand.contains(category) && (
            normalizedCommand.contains('headlines') || 
            normalizedCommand.contains('updates') || 
            normalizedCommand.contains('stories')))) {
        return true;
      }
      
      // Check for category + location combinations (e.g., "business in Hubli")
      for (final city in commonCities) {
        if (normalizedCommand.contains(category) && normalizedCommand.contains(city)) {
          return true;
        }
      }
    }
    
    // Check for location-based news with more patterns
    final List<String> locationPatterns = [
      'news in', 'news from', 'news about', 'news near', 'news of',
      'happening in', 'happening at', 'going on in', 'events in',
      'headlines from', 'headlines in', 'stories from', 'stories in',
      'updates from', 'updates in'
    ];
    
    for (final pattern in locationPatterns) {
      if (normalizedCommand.contains(pattern) && !normalizedCommand.contains('weather')) {
        return true;
      }
    }
    
    // Check for commands containing specific news app keywords
    if (normalizedCommand.contains('newsapi') || 
        normalizedCommand.contains('news api') ||
        normalizedCommand.contains('news feed') ||
        normalizedCommand.contains('news reader')) {
      return true;
    }
    
    return false;
  }

  // Custom widget to display feedback text with scrolling for long content
  Widget _buildFeedbackView() {
    // Check if the feedback is likely to be news (based on certain markers)
    final bool isLongContent = _feedbackText.length > 300;
    final bool isNewsContent = _feedbackText.contains('ARTICLE') && 
                               _feedbackText.contains('TITLE:') && 
                               _feedbackText.contains('SOURCE:');
    
    if (isNewsContent || isLongContent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add a hint about scrolling for news content
          if (isNewsContent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.newspaper,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'News Results · Scroll to Read More',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxHeight: isNewsContent ? 350 : 250, // More height for news
            ),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Scrollable content
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: _buildFormattedText(),
                  ),
                  
                  // Gradient overlay at the bottom to indicate more content
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.secondary.withOpacity(0.0),
                            AppColors.secondary.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // For short, non-news content, use the standard display
      return Text(
        _feedbackText,
        style: const TextStyle(
          color: AppColors.onSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    }
  }
  
  // Formats the text with better styling
  Widget _buildFormattedText() {
    if (_feedbackText.contains('ARTICLE') && _feedbackText.contains('TITLE:')) {
      // Split the text into articles
      final List<String> articles = _feedbackText.split('ARTICLE ');
      
      // Remove the first empty element if it exists
      if (articles.isNotEmpty && articles[0].trim().isEmpty) {
        articles.removeAt(0);
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: articles.map((articleText) {
          // Extract article number
          final String articleNumber = articleText.split('\n').first.trim();
          
          // The rest of the article content
          final String content = articleText.substring(articleNumber.length).trim();
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Article number header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ARTICLE $articleNumber',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Article content with formatted sections
                _buildFormattedArticleContent(content),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      // For non-news content, just display the text normally
      return Text(
        _feedbackText,
        style: const TextStyle(
          color: AppColors.onSecondary,
          fontSize: 16,
          height: 1.5,
        ),
      );
    }
  }
  
  // Helper method to format individual article content
  Widget _buildFormattedArticleContent(String content) {
    // Split the content into sections (TITLE, SOURCE, etc.)
    final List<String> lines = content.split('\n\n');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('TITLE:')) {
          return _buildArticleSection(
            line.substring(6).trim(),
            'TITLE',
            AppColors.accent,
            FontWeight.bold,
            18.0,
          );
        } else if (line.startsWith('SOURCE:')) {
          return _buildArticleSection(
            line.substring(7).trim(),
            'SOURCE',
            AppColors.primary,
            FontWeight.w500,
            14.0,
          );
        } else if (line.startsWith('PUBLISHED:')) {
          return _buildArticleSection(
            line.substring(10).trim(),
            'PUBLISHED',
            AppColors.surface,
            FontWeight.normal,
            14.0,
          );
        } else if (line.startsWith('DESCRIPTION:')) {
          return _buildArticleSection(
            line.substring(12).trim(),
            'DESCRIPTION',
            AppColors.onBackground.withOpacity(0.8),
            FontWeight.normal,
            16.0,
          );
        } else if (line.startsWith('CONTENT:')) {
          return _buildArticleSection(
            line.substring(8).trim(),
            'CONTENT',
            AppColors.onBackground.withOpacity(0.8),
            FontWeight.normal,
            15.0,
          );
        } else if (line.startsWith('LINK:')) {
          return _buildArticleSection(
            line.substring(5).trim(),
            'LINK',
            AppColors.accent,
            FontWeight.normal,
            14.0,
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              line,
              style: const TextStyle(
                color: AppColors.onSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          );
        }
      }).toList(),
    );
  }
  
  // Helper method to build each section of the article
  Widget _buildArticleSection(String content, String label, Color labelColor, FontWeight contentWeight, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              color: AppColors.onSecondary,
              fontWeight: contentWeight,
              fontSize: fontSize,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog to guide user to app settings
  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text(
            'Microphone Access Required',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This app needs microphone access to recognize voice commands.',
                style: TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please follow these steps:',
                style: TextStyle(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...const [
                '1. Tap "Open Settings" below',
                '2. Go to Permissions',
                '3. Enable Microphone permission',
                '4. Return to the app'
              ].map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  step,
                  style: TextStyle(
                    color: AppColors.onBackground,
                  ),
                ),
              )),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.primary,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // Inform user how to enable later
                setState(() {
                  _feedbackText = 'Voice commands disabled. Tap microphone icon to try again.';
                });
                _ttsService.speak('Voice commands disabled. Tap microphone icon to try again.');
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                final opened = await AppPermissionHandler.openSettings();
                if (!opened) {
                  setState(() {
                    _feedbackText = 'Could not open settings. Please open settings manually.';
                  });
                  await _ttsService.speak('Could not open settings. Please open settings manually.');
                }
              },
            ),
          ],
        );
      },
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