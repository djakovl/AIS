// lib/core/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'https://185.135.82.161:8037'; // Замените на ваш URL
  
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static const String tasksEndpoint = '/tasks';
  static const String statusesEndpoint = '/statuses';
  static const String prioritiesEndpoint = '/priorities';



}