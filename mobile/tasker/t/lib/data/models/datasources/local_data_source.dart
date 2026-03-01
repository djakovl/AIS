import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/status.dart';
import 'package:t/data/models/task.dart';


class LocalDataSource {
  static const String _tasksKey = 'tasks';

  static const List<Priority> priorities = [
    Priority(
      id: 4,
      name: 'Критический',
      color: '#e74c3c',
      eisenhowerQuad: 1,
      orderIndex: 1,
      isDefault: true,
    ),
    Priority(
      id: 3,
      name: 'Высокий',
      color: '#f39c12',
      eisenhowerQuad: 1,
      orderIndex: 2,
      isDefault: false,
    ),
    Priority(
      id: 2,
      name: 'Средний',
      color: '#f1c40f',
      eisenhowerQuad: 2,
      orderIndex: 3,
      isDefault: false,
    ),
    Priority(
      id: 1,
      name: 'Низкий',
      color: '#2ecc71',
      eisenhowerQuad: 3,
      orderIndex: 4,
      isDefault: false,
    ),
    
  ];

  static const List<Status> statuses = [
    Status(
      id: 1,
      name: 'Новая',
      color: '#3498db',
      orderIndex: 1,
      isDefault: true,
    ),
    Status(
      id: 2,
      name: 'В процессе',
      color: '#f39c12',
      orderIndex: 2,
      isDefault: false,
    ),
    Status(
      id: 3,
      name: 'Выполнена',
      color: '#27ae60',
      orderIndex: 3,
      isDefault: false,
    ),
    
    Status(
      id: 4,
      name: 'Отменена',
      color: '#e74c3c',
      orderIndex: 5,
      isDefault: false,
    ),
  ];

  Future<SharedPreferences> get _prefs async => 
      await SharedPreferences.getInstance();

  Future<List<Task>> getTasks() async {
    final prefs = await _prefs;
    final tasksJson = prefs.getStringList(_tasksKey) ?? [];
    
    if (tasksJson.isEmpty) {
      return _getTestTasks();
    }
    
    return tasksJson
        .map((json) => Task.fromJson(jsonDecode(json)))
        .map((task) {
          task.status = statuses.firstWhere((s) => s.id == task.statusId);
          task.priority = priorities.firstWhere((p) => p.id == task.priorityId);
          return task;
        })
        .toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await _prefs;
    final tasksJson = tasks.map((task) => jsonEncode(task.toJson())).toList();
    await prefs.setStringList(_tasksKey, tasksJson);
  }

  Future<void> addTask(Task task) async {
    final tasks = await getTasks();
    tasks.add(task);
    await saveTasks(tasks);
  }

  Future<void> updateTask(Task task) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      tasks[index] = task;
      await saveTasks(tasks);
    }
  }

  Future<void> deleteTask(String id) async {
    final tasks = await getTasks();
    tasks.removeWhere((t) => t.id == id);
    await saveTasks(tasks);
  }

  Future<Task?> getTaskById(String id) async {
    final tasks = await getTasks();
    try {
      return tasks.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
  List<Task> _getTestTasks() {
    final now = DateTime.now();
    
    return [
      Task(
        id: 'task_1',
        title: 'Сдать отчет по проекту',
        description: 'Подготовить ежеквартальный отчет',
        statusId: 'status_2',
        priorityId: 'prio_1',
        dueDate: DateTime(now.year, now.month, now.day + 2),
        isCompleted: false,
        orderIndex: 0,
        createdAt: now,
        updatedAt: now,
        status: statuses.firstWhere((s) => s.id == 'status_2'),
        priority: priorities.firstWhere((p) => p.id == 'prio_1'),
      ),
      Task(
        id: 'task_2',
        title: 'Исправить критический баг',
        description: 'Ошибка в продакшене',
        statusId: 'status_1',
        priorityId: 'prio_1',
        dueDate: DateTime(now.year, now.month, now.day + 1),
        isCompleted: false,
        orderIndex: 1,
        createdAt: now,
        updatedAt: now,
        status: statuses.firstWhere((s) => s.id == 'status_1'),
        priority: priorities.firstWhere((p) => p.id == 'prio_1'),
      ),
      Task(
        id: 'task_3',
        title: 'Подготовить презентацию',
        description: 'Для встречи с командой',
        statusId: 'status_2',
        priorityId: 'prio_2',
        dueDate: DateTime(now.year, now.month, now.day + 3),
        isCompleted: false,
        orderIndex: 2,
        createdAt: now,
        updatedAt: now,
        status: statuses.firstWhere((s) => s.id == 'status_2'),
        priority: priorities.firstWhere((p) => p.id == 'prio_2'),
      ),
      Task(
        id: 'task_4',
        title: 'Обновить документацию',
        description: 'API документация',
        statusId: 'status_1',
        priorityId: 'prio_3',
        dueDate: DateTime(now.year, now.month, now.day + 4),
        isCompleted: false,
        orderIndex: 3,
        createdAt: now,
        updatedAt: now,
        status: statuses.firstWhere((s) => s.id == 'status_1'),
        priority: priorities.firstWhere((p) => p.id == 'prio_3'),
      ),
      Task(
        id: 'task_5',
        title: 'Позвонить поставщику',
        description: 'Уточнить сроки поставки',
        statusId: 'status_4',
        priorityId: 'prio_4',
        dueDate: DateTime(now.year, now.month, now.day + 5),
        isCompleted: false,
        orderIndex: 4,
        createdAt: now,
        updatedAt: now,
        status: statuses.firstWhere((s) => s.id == 'status_4'),
        priority: priorities.firstWhere((p) => p.id == 'prio_4'),
      ),
    ];
  }
}