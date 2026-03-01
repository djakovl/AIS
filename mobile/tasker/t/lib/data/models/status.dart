import 'dart:ui';

import 'package:flutter/material.dart';

class Status {
  final int id;  // 👈 ИЗМЕНИТЬ С String НА int
  final String name;
  final String color;
  final int orderIndex;
  final bool? isDefault;

  const Status({
    required this.id,
    required this.name,
    required this.color,
    required this.orderIndex,
    this.isDefault,
  });

  Color get flutterColor {
    
    switch (id) {
      case 1:  
        return Colors.blue;
      case 2:  
        return Colors.orange;
      case 3:
        return Colors.green;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.red;
      default:
        try {
          return Color(int.parse(color.replaceFirst('#', '0xff')));
        } catch (e) {
          return Colors.grey;
        }
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'order_index': orderIndex,
    if (isDefault != null) 'is_default': isDefault,
  };

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      id: json['id'] as int, 
      name: json['name'] ?? '',
      color: json['color'] ?? '#95a5a6',
      orderIndex: json['order_index'] ?? json['orderIndex'] ?? 0,
      isDefault: json['is_default'] ?? json['isDefault'],
    );
  }
}