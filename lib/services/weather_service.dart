import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/weather_data.dart';

class WeatherService {
  // Default API key as provided
  final String _defaultApiKey = 'cef73f60bcf74ba8be953645251704';
  final String _baseUrl = 'https://api.weatherapi.com/v1/current.json';
  
  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('weather_api_key') ?? _defaultApiKey;
  }
  
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_api_key', apiKey);
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }
  
  Future<WeatherData> getCurrentWeather() async {
    try {
      final apiKey = await _getApiKey();
      final position = await _getCurrentLocation();
      
      final response = await http.get(
        Uri.parse('$_baseUrl?key=$apiKey&q=${position.latitude},${position.longitude}'),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        throw Exception('Failed to load weather data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load weather data: $e');
    }
  }
  
  Future<String> getCurrentWeatherSummary() async {
    try {
      final weather = await getCurrentWeather();
      return weather.toString();
    } catch (e) {
      return 'Unable to get weather information at this time. Please try again later.';
    }
  }
} 