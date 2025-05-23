import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/weather_data.dart';

class WeatherService {
  // Default API key as provided - this is a valid WeatherAPI.com key
  final String _defaultApiKey = '3c9a8c0d5a4e4e0e9fd175828232306';
  final String _baseUrl = 'https://api.weatherapi.com/v1/current.json';
  
  Future<String> _getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('weather_api_key') ?? _defaultApiKey;
    } catch (e) {
      print('Error getting API key: $e');
      return _defaultApiKey;
    }
  }
  
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_api_key', apiKey);
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      print('Getting current position...');
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  Future<WeatherData?> getWeatherByCity(String city) async {
    try {
      final apiKey = await _getApiKey();
      print('Using API key: ${apiKey.substring(0, 5)}... for city: $city');
      
      final response = await http.get(
        Uri.parse('$_baseUrl?key=$apiKey&q=$city'),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Weather data fetched successfully for $city');
        return WeatherData.fromJson(data);
      } else {
        print('Failed to load weather data for $city. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error in getWeatherByCity: $e');
      return null;
    }
  }
  
  Future<WeatherData?> getCurrentWeather() async {
    try {
      final apiKey = await _getApiKey();
      print('Using API key: ${apiKey.substring(0, 5)}...');
      
      final position = await _getCurrentLocation();
      if (position == null) {
        print('Could not get location. Using default location.');
        // Use a default location (Hubli) as fallback
        return await getWeatherByCity('Hubli');
      }
      
      print('Location obtained: ${position.latitude}, ${position.longitude}');
      final response = await http.get(
        Uri.parse('$_baseUrl?key=$apiKey&q=${position.latitude},${position.longitude}'),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Weather data fetched successfully');
        return WeatherData.fromJson(data);
      } else {
        print('Failed to load weather data. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Fallback to default city if coordinates don't work
        return await getWeatherByCity('Hubli');
      }
    } catch (e) {
      print('Error in getCurrentWeather: $e');
      return await getWeatherByCity('Hubli');
    }
  }
  
  Future<String> getCurrentWeatherSummary() async {
    try {
      final weather = await getCurrentWeather();
      if (weather == null) {
        return 'Unable to get weather information at this time. Please try again later.';
      }
      return weather.toString();
    } catch (e) {
      print('Error in getCurrentWeatherSummary: $e');
      return 'Unable to get weather information at this time. Please try again later.';
    }
  }
  
  Future<String> getWeatherForCity(String city) async {
    try {
      final weather = await getWeatherByCity(city);
      if (weather == null) {
        return 'Unable to get weather information for $city at this time. Please try again later.';
      }
      return weather.toString();
    } catch (e) {
      print('Error in getWeatherForCity: $e');
      return 'Unable to get weather information for $city at this time. Please try again later.';
    }
  }
} 