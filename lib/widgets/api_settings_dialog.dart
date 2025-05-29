import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/news_service.dart';
import '../services/weather_service.dart';
import '../services/wake_word_service.dart';
import '../constants/app_constants.dart';

class ApiSettingsDialog extends StatefulWidget {
  final String initialType;
  
  const ApiSettingsDialog({
    super.key,
    required this.initialType,
  });
  
  @override
  State<ApiSettingsDialog> createState() => _ApiSettingsDialogState();
}

class _ApiSettingsDialogState extends State<ApiSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _newsApiController = TextEditingController();
  final TextEditingController _weatherApiController = TextEditingController();
  final TextEditingController _picovoiceApiController = TextEditingController();
  final NewsService _newsService = NewsService();
  final WeatherService _weatherService = WeatherService();
  final WakeWordService _wakeWordService = WakeWordService();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _getInitialTabIndex(),
    );
    _loadApiKeys();
  }
  
  int _getInitialTabIndex() {
    switch (widget.initialType) {
      case 'news': return 0;
      case 'weather': return 1;
      case 'picovoice': return 2;
      default: return 0;
    }
  }
  
  Future<void> _loadApiKeys() async {
    // Load saved keys from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _newsApiController.text = prefs.getString('news_api_key') ?? 
          '292738e336f44779b2db8aed22871538';
      _weatherApiController.text = prefs.getString('weather_api_key') ?? 
          'cef73f60bcf74ba8be953645251704';
      _picovoiceApiController.text = prefs.getString('picovoice_api_key') ?? 
          'LfzkiCmmySifFmlArrMKyaV3u9hjME3u9IC8YtBMd6wcMGgg9T45hg==';
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _newsApiController.dispose();
    _weatherApiController.dispose();
    _picovoiceApiController.dispose();
    super.dispose();
  }
  
  Future<void> _saveNewsApiKey() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _newsService.saveApiKey(_newsApiController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('News API key saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving News API key: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _saveWeatherApiKey() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _weatherService.saveApiKey(_weatherApiController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weather API key saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Weather API key: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _savePicovoiceApiKey() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _wakeWordService.saveApiKey(_picovoiceApiController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Picovoice API key saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Picovoice API key: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Settings'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'News API'),
                Tab(text: 'Weather API'),
                Tab(text: 'Picovoice API'),
              ],
              labelColor: AppColors.primary,
              indicatorColor: AppColors.accent,
              isScrollable: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // News API Tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter your NewsAPI.org API key:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _newsApiController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'News API Key',
                          isDense: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Default: 292738e336f44779b2db8aed22871538',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  
                  // Weather API Tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter your WeatherAPI.com API key:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _weatherApiController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Weather API Key',
                          isDense: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Default: cef73f60bcf74ba8be953645251704',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  
                  // Picovoice API Tab
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter your Picovoice API key:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _picovoiceApiController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Picovoice API Key',
                          isDense: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9=]')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'For "Hey Surya" wake word detection',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (_tabController.index == 0) {
                    await _saveNewsApiKey();
                  } else if (_tabController.index == 1) {
                    await _saveWeatherApiKey();
                  } else {
                    await _savePicovoiceApiKey();
                  }
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class ApiType {
  static const String news = 'news';
  static const String weather = 'weather';
  static const String picovoice = 'picovoice';
} 