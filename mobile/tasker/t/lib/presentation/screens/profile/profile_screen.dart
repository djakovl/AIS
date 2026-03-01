import 'package:flutter/material.dart';
import 'package:t/core/services/auth_api_service.dart';
import 'package:t/core/services/task_api_service.dart';
import 'package:t/data/models/auth_models.dart';
import 'package:t/data/models/task.dart';
import 'package:t/data/models/task_dto.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _userProfile;
  List<Task> _tasks = [];
  bool _isLoading = true;
  bool _isLoadingTasks = true;
  String? _error;
  String? _tasksError;


  int _totalTasks = 0;
  int _activeTasks = 0;
  int _completedTasks = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadTasks(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = AuthApiService();
      final profile = await authService.getProfile();
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
        
        if (e.code == 'UNAUTHORIZED') {
          _redirectToLogin();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки профиля';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoadingTasks = true;
      _tasksError = null;
    });

    try {
 
      final tasks = await TaskApi.listTasks(params: TaskFilter(limit: 100));
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _updateTaskStats();
          _isLoadingTasks = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _tasksError = 'Ошибка загрузки задач: ${e.message}';
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tasksError = 'Ошибка загрузки задач';
          _isLoadingTasks = false;
        });
      }
    }
  }

  void _updateTaskStats() {
    _totalTasks = _tasks.length;
    _activeTasks = _tasks.where((task) => !task.isCompleted).length;
    _completedTasks = _tasks.where((task) => task.isCompleted).length;
  }

  Future<void> _logout() async {
    try {
      final authService = AuthApiService();
      await authService.logout();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Вы успешно вышли из аккаунта'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        _redirectToLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ошибка при выходе из аккаунта'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _redirectToLogin() {
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/login', 
      (route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выход'),
          content: const Text('Вы уверены, что хотите выйти?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );
  }

  String _getInitials() {
    if (_userProfile != null) {
      if (_userProfile!.firstName != null && _userProfile!.firstName!.isNotEmpty) {
        return _userProfile!.firstName![0].toUpperCase();
      }
      return _userProfile!.username[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingTasks) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.blue,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Карточка профиля
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Аватар с инициалами
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue, Colors.blueAccent],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Имя пользователя
                    Text(
                      _userProfile?.fullName ?? _userProfile?.username ?? 'Пользователь',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    // Username
                    if (_userProfile?.username != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '@${_userProfile!.username}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Email
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _userProfile?.email ?? 'email@example.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Статистика задач
                    if (_tasksError != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _tasksError!,
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatColumn(_totalTasks.toString(), 'Всего задач'),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          _buildStatColumn(_activeTasks.toString(), 'Активных'),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          _buildStatColumn(_completedTasks.toString(), 'Завершено'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Кнопка выхода
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade100),
              ),
              color: Colors.red.shade50,
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.red.shade700,
                ),
                title: Text(
                  'Выйти из аккаунта',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade700,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red.shade400,
                ),
                onTap: () => _showLogoutDialog(context),
              ),
            ),
           
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}