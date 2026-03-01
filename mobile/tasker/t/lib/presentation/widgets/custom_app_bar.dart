import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onMenuPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title,
        style: const TextStyle(color: Colors.white),),
        backgroundColor: Colors.blue, 
      foregroundColor: Colors.white, 
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: onMenuPressed,
      ),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            
            
          ],
        ),
        
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}