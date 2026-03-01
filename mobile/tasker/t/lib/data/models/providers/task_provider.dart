import 'package:flutter/material.dart';
import 'package:t/core/services/task_api_service.dart';
import 'package:t/data/models/task.dart';
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/task_dto.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  String _selectedFilter = 'Все';
  Priority? _selectedPriority;
  bool _isLoading = false;
  String? _error;

  TaskProvider();

  List<Task> get tasks => _tasks;
  String get selectedFilter => _selectedFilter;
  Priority? get selectedPriority => _selectedPriority;
  bool get isLoading => _isLoading;
  String? get error => _error;

  
Future<void> loadTasks() async {
  _setLoading(true);
  try {
    final filter = TaskFilter(
      isCompleted: _selectedFilter == 'Активные' ? false : 
                   (_selectedFilter == 'Выполненные' ? true : null),
      priorityId: _selectedPriority?.id?.toString(), 
    );
    
    final tasks = await TaskApi.listTasks(params: filter);
    _tasks = tasks;
    _error = null;
  } catch (e) {
    _error = 'Ошибка загрузки задач: $e';
  } finally {
    _setLoading(false);
  }
}

  Future<void> updateTask(Task task) async {
    _setLoading(true);
    try {
      final Map<String, dynamic> updateData = {
        'title': task.title,
        'description': task.description,
        'status_id': task.statusId,  
        'priority_id': task.priorityId,  
        'due_date': task.dueDate?.toIso8601String(),
        'is_completed': task.isCompleted,
      };
      
      final updatedTask = await TaskApi.updateTask(task.id, updateData);
      
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка обновления задачи: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTask(String taskId) async {
    _setLoading(true);
    try {
      await TaskApi.deleteTask(taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка удаления задачи: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<Task?> getTask(String taskId) async {
    try {
      return await TaskApi.getTask(taskId);
    } catch (e) {
      _error = 'Ошибка загрузки задачи: $e';
      return null;
    }
  }

  List<Task> getFilteredTasks() {
    return _tasks.where((task) {
      if (_selectedFilter == 'Активные' && task.isCompleted) return false;
      if (_selectedFilter == 'Выполненные' && !task.isCompleted) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
  }

  void setSelectedPriority(Priority? priority) {
    _selectedPriority = priority;
    loadTasks();
  }

  void setSelectedFilter(String filter) {
    _selectedFilter = filter;
    loadTasks();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}