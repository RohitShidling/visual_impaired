import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  // In a real app, this should be stored securely, not hardcoded
  final String _apiKey = 'YOUR_OPENWEATHERMAP_API_KEY';
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  Future<WeatherData> getWeatherByCity(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?q=$city&units=metric&appid=$_apiKey'),
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
  
  Future<String> getCurrentWeatherSummary(String city) async {
    try {
      final weather = await getWeatherByCity(city);
      return weather.toString();
    } catch (e) {
      return 'Unable to get weather information at this time. Please try again later.';
    }
  }
} 