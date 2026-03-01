import 'package:flutter/material.dart';
import '../../data/models/priority.dart';

class PriorityChip extends StatelessWidget {
  final Priority priority;

  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: priority.flutterColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.shortName,
        style: TextStyle(
          fontSize: 10, 
          color: priority.flutterColor, 
          fontWeight: FontWeight.w500
        ),
      ),
    );
  }
}