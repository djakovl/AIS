// lib/data/models/auth_models.dart

class RegisterRequest {
  final String email;
  final String username;
  final String? firstName;
  final String? lastName;
  final String password;
  final String passwordConfirm;

  RegisterRequest({
    required this.email,
    required this.username,
    this.firstName,
    this.lastName,
    required this.password,
    required this.passwordConfirm,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'email': email,
      'username': username,
      'password': password,
      'password_confirm': passwordConfirm,
    };
    
    if (firstName != null && firstName!.isNotEmpty) {
      map['first_name'] = firstName!;
    }
    if (lastName != null && lastName!.isNotEmpty) {
      map['last_name'] = lastName!;
    }
    
    return map;
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

class LoginResponse {
  final String? accessToken;
  final String? refreshToken;
  final String? sessionId;
  final String? csrfToken; 
  final UserProfile? user;

  LoginResponse({
    this.accessToken,
    this.refreshToken,
    this.sessionId,
    this.csrfToken, 
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    return LoginResponse(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
      sessionId: data['session_id'],
      csrfToken: data['csrf_token'], 
      user: data['user'] != null ? UserProfile.fromJson(data['user']) : null,
    );
  }
}

class AuthResponse {
  final String message;
  final UserProfile? user;

  AuthResponse({
    required this.message,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return AuthResponse(
      message: data['message'] ?? '',
      user: data['user'] != null ? UserProfile.fromJson(data['user']) : null,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String username;
  final String? firstName;
  final String? lastName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String>? roles;
  final bool? isActive;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.firstName,
    this.lastName,
    this.createdAt,
    this.updatedAt,
    this.roles,
    this.isActive,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      roles: json['roles'] != null ? List<String>.from(json['roles']) : null,
      isActive: json['is_active'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return username;
    }
  }
}

class AuthException implements Exception {
  final String message;
  final String code;

  AuthException({
    required this.message,
    required this.code,
  });

  @override
  String toString() => 'AuthException: $code - $message';
}