import 'dart:ui';

import 'package:flutter/material.dart';

class Priority {
  final int id;  // 👈 ИЗМЕНИТЬ С String НА int
  final String name;
  final String color;
  final int eisenhowerQuad;
  final int orderIndex;
  final bool? isDefault;

  const Priority({
    required this.id,
    required this.name,
    required this.color,
    required this.eisenhowerQuad,
    required this.orderIndex,
    this.isDefault,
  });

  Color get flutterColor {
    switch (id) {  
      case 4:  
        return Colors.red;
      case 3:  
        return Colors.orange;
      case 2:
        return Colors.amber;
      case 1:
        return Colors.green;
      case 5:
        return Colors.grey;
      default:
        try {
          return Color(int.parse(color.replaceFirst('#', '0xff')));
        } catch (e) {
          return Colors.blue;
        }
    }
  }

  String get displayName {
    return name.replaceFirst(RegExp(r'P\d - '), '');
  }

  String get shortName {
    switch (orderIndex) {
      case 1:
        return 'Критический';
      case 2:
        return 'Высокий';
      case 3:
        return 'Средний';
      case 4:
        return 'Низкий';
      case 5:
        return 'Опционально';
      default:
        return name.length > 10 ? '${name.substring(0, 10)}...' : name;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,  // Теперь число
    'name': name,
    'color': color,
    'eisenhower_quad': eisenhowerQuad,
    'order_index': orderIndex,
    if (isDefault != null) 'is_default': isDefault,
  };

  factory Priority.fromJson(Map<String, dynamic> json) {
    return Priority(
      id: json['id'] as int,  // 👈 Парсим как int
      name: json['name'] ?? '',
      color: json['color'] ?? '#3498db',
      eisenhowerQuad: json['eisenhower_quad'] ?? json['eisenhowerQuad'] ?? 0,
      orderIndex: json['order_index'] ?? json['orderIndex'] ?? 0,
      isDefault: json['is_default'] ?? json['isDefault'],
    );
  }
}