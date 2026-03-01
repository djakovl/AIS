// lib/data/models/task.dart (обновленный)
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/status.dart';

class Task {
  final String id;
  final String? parentTaskId;
  final String title;
  final String? description;
  final String statusId;
  final String priorityId;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final bool isCompleted;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId; 

  Status? status;
  Priority? priority;

  Task({
    required this.id,
    this.parentTaskId,
    required this.title,
    this.description,
    required this.statusId,
    required this.priorityId,
    this.dueDate,
    this.completedAt,
    required this.isCompleted,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
    this.userId, 
    this.status,
    this.priority,
  });

  Task copyWith({
    String? id,
    String? parentTaskId,
    String? title,
    String? description,
    String? statusId,
    String? priorityId,
    DateTime? dueDate,
    DateTime? completedAt,
    bool? isCompleted,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    Status? status,
    Priority? priority,
  }) {
    return Task(
      id: id ?? this.id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      statusId: statusId ?? this.statusId,
      priorityId: priorityId ?? this.priorityId,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_task_id': parentTaskId, 
    'title': title,
    'description': description,
    'status_id': statusId,
    'priority_id': priorityId,
    'due_date': dueDate?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'is_completed': isCompleted,
    'order_index': orderIndex,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (userId != null) 'user_id': userId,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
 
    final taskData = json['data'] ?? json;
    
    return Task(
      id: taskData['id']?.toString() ?? '',
      parentTaskId: taskData['parent_task_id']?.toString() ?? taskData['parentTaskId']?.toString(),
      title: taskData['title'] ?? '',
      description: taskData['description'],
      statusId: taskData['status_id']?.toString() ?? taskData['statusId']?.toString() ?? '',
      priorityId: taskData['priority_id']?.toString() ?? taskData['priorityId']?.toString() ?? '',
      dueDate: taskData['due_date'] != null 
          ? DateTime.parse(taskData['due_date']) 
          : (taskData['dueDate'] != null ? DateTime.parse(taskData['dueDate']) : null),
      completedAt: taskData['completed_at'] != null 
          ? DateTime.parse(taskData['completed_at']) 
          : (taskData['completedAt'] != null ? DateTime.parse(taskData['completedAt']) : null),
      isCompleted: taskData['is_completed'] ?? taskData['isCompleted'] ?? false,
      orderIndex: taskData['order_index'] ?? taskData['orderIndex'] ?? 0,
      createdAt: taskData['created_at'] != null 
          ? DateTime.parse(taskData['created_at']) 
          : (taskData['createdAt'] != null ? DateTime.parse(taskData['createdAt']) : DateTime.now()),
      updatedAt: taskData['updated_at'] != null 
          ? DateTime.parse(taskData['updated_at']) 
          : (taskData['updatedAt'] != null ? DateTime.parse(taskData['updatedAt']) : DateTime.now()),
      userId: taskData['user_id']?.toString() ?? taskData['userId']?.toString(),
    
      status: taskData['status'] != null 
          ? Status.fromJson(taskData['status']) 
          : null,
      priority: taskData['priority'] != null 
          ? Priority.fromJson(taskData['priority']) 
          : null,
    );
  }
}