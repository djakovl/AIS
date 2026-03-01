import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:t/data/models/auth_models.dart';

class SecureStorage {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _sessionIdKey = 'session_id';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _usernameKey = 'username';
  static const String _firstNameKey = 'first_name';
  static const String _lastNameKey = 'last_name';
  static const String _csrfTokenKey = 'csrf_token';

  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // Токены
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // Сессия
  Future<void> saveSessionId(String sessionId) async {
    await _storage.write(key: _sessionIdKey, value: sessionId);
  }

  Future<String?> getSessionId() async {
    return await _storage.read(key: _sessionIdKey);
  }

  // Данные пользователя
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _userEmailKey, value: email);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _userEmailKey);
  }

  Future<void> saveUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  Future<void> saveFirstName(String firstName) async {
    await _storage.write(key: _firstNameKey, value: firstName);
  }

  Future<String?> getFirstName() async {
    return await _storage.read(key: _firstNameKey);
  }

  Future<void> saveLastName(String lastName) async {
    await _storage.write(key: _lastNameKey, value: lastName);
  }

  Future<String?> getLastName() async {
    return await _storage.read(key: _lastNameKey);
  }
  
  Future<void> saveCsrfToken(String csrfToken) async {
    await _storage.write(key: _csrfTokenKey, value: csrfToken);
  }

  Future<String?> getCsrfToken() async {
    return await _storage.read(key: _csrfTokenKey);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await saveUserId(profile.id);
    await saveUserEmail(profile.email);
    await saveUsername(profile.username);
    if (profile.firstName != null) {
      await saveFirstName(profile.firstName!);
    }
    if (profile.lastName != null) {
      await saveLastName(profile.lastName!);
    }
  }

  Future<Map<String, String>> getAllKeys() async {
    return await _storage.readAll();
  }


  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final userId = await getUserId();
    final token = await getToken();
    final sessionId = await getSessionId();
    return userId != null || token != null || sessionId != null;
  }
}