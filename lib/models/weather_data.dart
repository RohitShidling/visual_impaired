class WeatherData {
  final String condition;
  final double temperature;
  final String city;
  final double humidity;
  final double windSpeed;
  
  WeatherData({
    required this.condition,
    required this.temperature,
    required this.city,
    required this.humidity,
    required this.windSpeed,
  });
  
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: json['weather'][0]['description'],
      temperature: json['main']['temp'].toDouble(),
      city: json['name'],
      humidity: json['main']['humidity'].toDouble(),
      windSpeed: json['wind']['speed'].toDouble(),
    );
  }
  
  @override
  String toString() {
    return 'Current weather in $city: $condition, ${temperature.toStringAsFixed(1)} degrees Celsius, humidity ${humidity.toStringAsFixed(0)}%, wind speed ${windSpeed.toStringAsFixed(1)} meters per second';
  }
} 