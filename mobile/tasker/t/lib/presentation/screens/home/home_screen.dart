import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_api_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../data/models/auth_models.dart';
import '../../widgets/custom_app_bar.dart';
import '../tasks/tasks_screen.dart';
import '../profile/profile_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  final List<Widget> _pages = [
    const TasksScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = ['Задачи', 'Профиль'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final authService = AuthApiService();
      final profile = await authService.getProfile();
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
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
        
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/login', 
          (route) => false
        );
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выход'),
          content: const Text('Вы уверены, что хотите выйти?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: _titles[_selectedIndex],
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Задачи',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Профиль',
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(context),
    );
  }

 Widget _buildDrawer(BuildContext context) {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
      
        DrawerHeader(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue, Colors.blueAccent],
            ),
          ),
          child: _isLoadingProfile
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                  
                    Container(
                      width: 50,
                      height: 50, 
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2), 
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(),
                          style: const TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8), 
                   
                    Text(
                      _userProfile?.fullName ?? _userProfile?.username ?? 'Пользователь',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                    Text(
                      _userProfile?.email ?? 'email@example.com',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12, 
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (_userProfile?.username != null)
                      Text(
                        '@${_userProfile!.username}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11, 
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
        ),
        
        ListTile(
          leading: Icon(
            Icons.home_outlined,
            color: _selectedIndex == 0 ? Colors.blue : Colors.grey.shade700,
          ),
          title: Text(
            'Задачи',
            style: TextStyle(
              color: _selectedIndex == 0 ? Colors.blue : Colors.grey.shade800,
              fontWeight: _selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: _selectedIndex == 0,
          onTap: () {
            setState(() => _selectedIndex = 0);
            Navigator.pop(context);
          },
        ),
        
        ListTile(
          leading: Icon(
            Icons.person_outline,
            color: _selectedIndex == 1 ? Colors.blue : Colors.grey.shade700,
          ),
          title: Text(
            'Профиль',
            style: TextStyle(
              color: _selectedIndex == 1 ? Colors.blue : Colors.grey.shade800,
              fontWeight: _selectedIndex == 1 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: _selectedIndex == 1,
          onTap: () {
            setState(() => _selectedIndex = 1);
            Navigator.pop(context);
          },
        ),
        
        
        
        const Divider(),
        
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            'Выйти',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
          ),
          onTap: () {
            Navigator.pop(context);
            _showLogoutDialog(context);
          },
        ),
        
        
      ],
    ),
  );
}
  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройки'),
        content: const Text('Страница настроек в разработке'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Помощь'),
        content: const Text('Справочный центр в разработке'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Tasker',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.task, size: 50),
      children: const [
        SizedBox(height: 10),
        Text('Приложение для управления задачами'),
      ],
    );
  }
}