import 'package:flutter/material.dart';
import '../../data/models/status.dart';

class StatusChip extends StatelessWidget {
  final Status status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status.flutterColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name,
        style: TextStyle(
          fontSize: 10,
          color: status.flutterColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}