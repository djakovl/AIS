// lib/core/services/auth_interceptor.dart
import 'package:http/http.dart' as http;
import 'auth_api_service.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor {
  final AuthApiService _authService;
  final SecureStorage _secureStorage;

  AuthInterceptor({
    AuthApiService? authService,
    SecureStorage? secureStorage,
  })  : _authService = authService ?? AuthApiService(),
        _secureStorage = secureStorage ?? SecureStorage();

  Future<http.Response> interceptRequest(Future<http.Response> Function() request) async {
    try {
      var response = await request();
    
      if (response.statusCode == 401) {
        final newToken = await _authService.refreshToken();
        
        if (newToken != null) {
          response = await request();
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
}