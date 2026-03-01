import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;
import 'package:t/data/models/auth_models.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'dart:io';

class AuthApiService {
  final http.Client _client;
  final SecureStorage _secureStorage;

  AuthApiService({
    http.Client? client,
    SecureStorage? secureStorage,
  })  : _client = client ?? _createHttpClient(),
        _secureStorage = secureStorage ?? SecureStorage();

  static http.Client _createHttpClient() {
    final HttpClient httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return http.IOClient(httpClient);
  }

  String _getStatusCategory(int statusCode) {
    if (statusCode >= 100 && statusCode < 200) return 'Informational';
    if (statusCode >= 200 && statusCode < 300) return 'Success';
    if (statusCode >= 300 && statusCode < 400) return 'Redirection';
    if (statusCode >= 400 && statusCode < 500) return 'Client Error';
    if (statusCode >= 500 && statusCode < 600) return 'Server Error';
    return 'Unknown';
  }

  String _getStatusDescription(int statusCode) {
    switch (statusCode) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 409: return 'Conflict';
      case 422: return 'Unprocessable Entity';
      case 429: return 'Too Many Requests';
      case 500: return 'Internal Server Error';
      case 502: return 'Bad Gateway';
      case 503: return 'Service Unavailable';
      case 504: return 'Gateway Timeout';
      default: return 'HTTP $statusCode';
    }
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    const method = 'POST';
    const endpoint = '/auth/register';
    final url = '${ApiConstants.baseUrl}$endpoint';
    
    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: ApiConstants.headers,
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 10));

      final responseData = _safeParseJson(response.body);

      if (response.statusCode == 201) {
        return AuthResponse.fromJson(responseData);
      } else if (response.statusCode == 409) {
        throw AuthException(
          message: responseData['message'] ?? 'Пользователь уже существует',
          code: 'USER_EXISTS',
        );
      } else {
        throw AuthException(
          message: responseData['message'] ?? 'Ошибка регистрации',
          code: responseData['code'] ?? 'REGISTRATION_ERROR',
        );
      }
    } on SocketException {
      throw AuthException(
        message: 'Не удалось подключиться к серверу. Проверьте интернет-соединение.',
        code: 'CONNECTION_ERROR',
      );
    } on TimeoutException {
      throw AuthException(
        message: 'Превышено время ожидания ответа от сервера',
        code: 'TIMEOUT_ERROR',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Ошибка сети при регистрации',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<LoginResponse> login(LoginRequest request) async {
    const method = 'POST';
    const endpoint = '/auth/login';
    final url = '${ApiConstants.baseUrl}$endpoint';
    
    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: ApiConstants.headers,
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 10));

      final responseData = _safeParseJson(response.body);

      if (response.statusCode == 200) {
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          await _extractAndSaveSessionId(cookies);
        }

        final loginResponse = LoginResponse.fromJson(responseData);
        
        if (loginResponse.accessToken != null) {
          await _secureStorage.saveToken(loginResponse.accessToken!);
        }
        if (loginResponse.refreshToken != null) {
          await _secureStorage.saveRefreshToken(loginResponse.refreshToken!);
        }
        if (loginResponse.sessionId != null) {
          await _secureStorage.saveSessionId(loginResponse.sessionId!);
        }
        if (loginResponse.csrfToken != null) {
          await _secureStorage.saveCsrfToken(loginResponse.csrfToken!);
        }
        
        if (loginResponse.user != null) {
          await _secureStorage.saveUserId(loginResponse.user!.id);
          await _secureStorage.saveUserEmail(loginResponse.user!.email);
          await _secureStorage.saveUsername(loginResponse.user!.username);
          
          if (loginResponse.user!.firstName != null) {
            await _secureStorage.saveFirstName(loginResponse.user!.firstName!);
          }
          if (loginResponse.user!.lastName != null) {
            await _secureStorage.saveLastName(loginResponse.user!.lastName!);
          }
        }

        return loginResponse;
      } else if (response.statusCode == 401) {
        throw AuthException(
          message: responseData['message'] ?? 'Неверный email или пароль',
          code: 'INVALID_CREDENTIALS',
        );
      } else {
        throw AuthException(
          message: responseData['message'] ?? 'Ошибка входа',
          code: responseData['code'] ?? 'LOGIN_ERROR',
        );
      }
    } on SocketException {
      throw AuthException(
        message: 'Не удалось подключиться к серверу. Проверьте интернет-соединение.',
        code: 'CONNECTION_ERROR',
      );
    } on TimeoutException {
      throw AuthException(
        message: 'Превышено время ожидания ответа от сервера',
        code: 'TIMEOUT_ERROR',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Ошибка сети при входе',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<void> logout() async {
    const method = 'DELETE';
    const endpoint = '/auth/logout';
    final url = '${ApiConstants.baseUrl}$endpoint';
    
    final sessionId = await _secureStorage.getSessionId();
    final token = await _secureStorage.getToken();

    final client = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    
    try {
      final request = await client.deleteUrl(Uri.parse(url));
      
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      if (sessionId != null) {
        request.headers.set('Cookie', 'session_id=$sessionId');
      }
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }

      await request.close();
    } catch (e) {
      // Ignore network errors during logout
    } finally {
      await _secureStorage.clearAll();
      client.close();
    }
  }

  Future<UserProfile> getProfile() async {
    const method = 'GET';
    const endpoint = '/auth/profile';
    final url = '${ApiConstants.baseUrl}$endpoint';
    
    final userId = await _secureStorage.getUserId();
    final sessionId = await _secureStorage.getSessionId();
    final token = await _secureStorage.getToken();

    if (userId == null || sessionId == null) {
      throw AuthException(
        message: 'Пользователь не авторизован',
        code: 'UNAUTHORIZED',
      );
    }

    final client = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    
    try {
      final request = await client.getUrl(Uri.parse(url));
      
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      request.headers.set('X-User-Id', userId);
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      request.headers.set('Cookie', 'session_id=$sessionId');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final statusCode = response.statusCode;
      final responseData = _safeParseJson(responseBody);

      if (statusCode == 200) {
        return UserProfile.fromJson(responseData['data'] ?? responseData);
      } else if (statusCode == 401) {
        throw AuthException(
          message: responseData['error']?['message'] ?? 'Требуется авторизация',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw AuthException(
          message: responseData['error']?['message'] ?? 'Ошибка получения профиля',
          code: responseData['error']?['code'] ?? 'PROFILE_ERROR',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Ошибка сети при получении профиля',
        code: 'NETWORK_ERROR',
      );
    } finally {
      client.close();
    }
  }

  Future<String?> refreshToken() async {
    const method = 'POST';
    const endpoint = '/auth/refresh';
    final url = '${ApiConstants.baseUrl}$endpoint';
    
    final refreshToken = await _secureStorage.getRefreshToken();

    if (refreshToken == null) {
      return null;
    }

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: ApiConstants.headers,
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['access_token'];
        
        if (newToken != null) {
          await _secureStorage.saveToken(newToken);
          return newToken;
        }
      }
    } catch (e) {
      // Ignore errors during token refresh
    }
    return null;
  }

  Map<String, dynamic> _safeParseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Future<void> _extractAndSaveSessionId(String cookieHeader) async {
    final cookies = cookieHeader.split(';');
    
    for (var cookie in cookies) {
      cookie = cookie.trim();
      if (cookie.startsWith('session_id=')) {
        final sessionId = cookie.substring(11);
        await _secureStorage.saveSessionId(sessionId);
        break;
      }
    }
  }
}