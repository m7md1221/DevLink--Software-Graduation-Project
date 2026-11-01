import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class WeatherData {
  final String city;
  final String country;
  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final String timezone;
  final double latitude;
  final double longitude;

  WeatherData({
    required this.city,
    required this.country,
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.timezone,
    required this.latitude,
    required this.longitude,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return WeatherData(
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      temperature: parseDouble(json['temperature']),
      weatherCode: parseInt(json['weatherCode']),
      windSpeed: parseDouble(json['windSpeed']),
      timezone: json['timezone']?.toString() ?? 'UTC',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
    );
  }

  String get weatherIcon {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 3) return '⛅';
    if (weatherCode <= 48) return '🌫️';
    if (weatherCode <= 57) return '🌧️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '❄️';
    if (weatherCode <= 82) return '🌧️';
    if (weatherCode <= 86) return '❄️';
    if (weatherCode >= 95) return '⛈️';
    return '🌤️';
  }

  String get weatherText {
    if (weatherCode == 0) return 'Clear';
    if (weatherCode <= 3) return 'Partly Cloudy';
    if (weatherCode <= 48) return 'Foggy';
    if (weatherCode <= 57) return 'Drizzle';
    if (weatherCode <= 67) return 'Rainy';
    if (weatherCode <= 77) return 'Snowy';
    if (weatherCode <= 82) return 'Showers';
    if (weatherCode <= 86) return 'Snow Showers';
    if (weatherCode >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }
}

class WeatherService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5133';
    if (Platform.isAndroid) return 'http://10.0.2.2:5133';
    return 'http://localhost:5133';
  }

  static Future<WeatherData?> getWeather(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/Posts/weather/$userId'),
      );
      if (response.statusCode == 200) {
        return WeatherData.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<WeatherData?> getWeatherByLocation(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/Posts/weather-location?lat=$lat&lon=$lon'),
      );
      if (response.statusCode == 200) {
        return WeatherData.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print("❌ Weather Location Error: $e");
      return null;
    }
  }
}