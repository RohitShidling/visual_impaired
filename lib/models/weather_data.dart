class WeatherData {
  final String condition;
  final double tempC;
  final String locationName;
  final String region;
  final String country;
  final int humidity;
  final double windKph;
  final int cloud;
  
  WeatherData({
    required this.condition,
    required this.tempC,
    required this.locationName,
    required this.region,
    required this.country,
    required this.humidity,
    required this.windKph,
    required this.cloud,
  });
  
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: json['current']['condition']['text'],
      tempC: json['current']['temp_c'].toDouble(),
      locationName: json['location']['name'],
      region: json['location']['region'],
      country: json['location']['country'],
      humidity: json['current']['humidity'],
      windKph: json['current']['wind_kph'].toDouble(),
      cloud: json['current']['cloud'],
    );
  }
  
  @override
  String toString() {
    return 'city: $locationName, temperature: ${tempC.toStringAsFixed(1)} Celsius';
  }
} 