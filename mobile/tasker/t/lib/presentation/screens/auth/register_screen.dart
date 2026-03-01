import 'package:flutter/material.dart';
import 'package:t/core/services/auth_api_service.dart';
import 'package:t/data/models/auth_models.dart';
import '../../../core/utils/validators.dart';
import 'dart:developer' as developer;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    developer.log(
      '📱 Экран регистрации открыт',
      name: 'RegisterScreen',
      time: DateTime.now(),
    );
  }

  @override
  void dispose() {
    developer.log(
      '📱 Экран регистрации закрыт',
      name: 'RegisterScreen',
      time: DateTime.now(),
    );
    _emailController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    developer.log(
      '🔄 Начало процесса регистрации',
      name: 'RegisterScreen',
      time: DateTime.now(),
    );
    
    developer.log(
      '📝 Данные формы:',
      name: 'RegisterScreen',
      error: {
        'email': _emailController.text,
        'username': _usernameController.text,
        'firstName': _firstNameController.text.isEmpty ? null : _firstNameController.text,
        'lastName': _lastNameController.text.isEmpty ? null : _lastNameController.text,
      },
      time: DateTime.now(),
    );
    
    final isValid = _formKey.currentState!.validate();
    developer.log(
      isValid ? '✅ Валидация успешна' : '❌ Ошибка валидации',
      name: 'RegisterScreen',
      time: DateTime.now(),
    );
    
    if (isValid) {
      developer.log('⏳ Загрузка начата', name: 'RegisterScreen');
      setState(() => _isLoading = true);
      
      try {
        final request = RegisterRequest(
          email: _emailController.text,
          username: _usernameController.text,
          firstName: _firstNameController.text.isEmpty 
              ? null 
              : _firstNameController.text,
          lastName: _lastNameController.text.isEmpty 
              ? null 
              : _lastNameController.text,
          password: _passwordController.text,
          passwordConfirm: _confirmPasswordController.text,
        );

        developer.log(
          '🚀 Отправка запроса на регистрацию',
          name: 'RegisterScreen',
          error: {
            'email': request.email,
            'username': request.username,
          },
          time: DateTime.now(),
        );

        final authService = AuthApiService();
        final response = await authService.register(request);

        developer.log(
          '✅ Регистрация успешна: ${response.message}',
          name: 'RegisterScreen',
          time: DateTime.now(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          developer.log('🔄 Переход на /login', name: 'RegisterScreen');
          Navigator.pushReplacementNamed(context, '/login');
        }
      } on AuthException catch (e) {
        developer.log(
          '❌ Ошибка регистрации: ${e.code} - ${e.message}',
          name: 'RegisterScreen',
          error: {'code': e.code, 'message': e.message},
          time: DateTime.now(),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        developer.log(
          '❌ Неизвестная ошибка: $e',
          name: 'RegisterScreen',
          error: e.toString(),
          time: DateTime.now(),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Произошла неизвестная ошибка'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        developer.log('⏳ Загрузка завершена', name: 'RegisterScreen');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            developer.log('👈 Нажата кнопка назад', name: 'RegisterScreen');
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              Container(
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.person_add,
                  size: 45,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Создать аккаунт',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                'Заполните форму для регистрации',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
           
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                          decoration: _buildInputDecoration(
                            label: 'Email *',
                            icon: Icons.email_outlined,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            developer.log('✏️ Email: $value', name: 'RegisterScreen');
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _usernameController,
                          validator: Validators.validateUsername,
                          decoration: _buildInputDecoration(
                            label: 'Имя пользователя *',
                            icon: Icons.person_outline,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            developer.log('✏️ Username: $value', name: 'RegisterScreen');
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _firstNameController,
                          decoration: _buildInputDecoration(
                            label: 'Имя',
                            icon: Icons.badge_outlined,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              developer.log('✏️ Имя: $value', name: 'RegisterScreen');
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _lastNameController,
                          decoration: _buildInputDecoration(
                            label: 'Фамилия',
                            icon: Icons.badge_outlined,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              developer.log('✏️ Фамилия: $value', name: 'RegisterScreen');
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          validator: Validators.validatePassword,
                          decoration: _buildInputDecoration(
                            label: 'Пароль *',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                developer.log(
                                  _isPasswordVisible ? '👁️ Пароль скрыт' : '👁️ Пароль показан',
                                  name: 'RegisterScreen',
                                );
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: _buildInputDecoration(
                            label: 'Подтверждение пароля *',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                developer.log(
                                  _isConfirmPasswordVisible ? '👁️ Подтверждение скрыто' : '👁️ Подтверждение показано',
                                  name: 'RegisterScreen',
                                );
                                setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) => Validators.validateConfirmPassword(
                            value, 
                            _passwordController.text
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '* Обязательные поля',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Кнопка регистрации
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        developer.log('🖱️ Нажата кнопка регистрации', name: 'RegisterScreen');
                        _register();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ЗАРЕГИСТРИРОВАТЬСЯ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
              
              const SizedBox(height: 20),
              
              // Ссылка на вход
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Уже есть аккаунт? ",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      developer.log('🖱️ Нажата ссылка "Войти"', name: 'RegisterScreen');
                      developer.log('🔄 Переход на /login', name: 'RegisterScreen');
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Войти',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade700,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: Colors.blue.shade400,
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}