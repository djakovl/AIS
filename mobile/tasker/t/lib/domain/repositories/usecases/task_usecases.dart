import 'package:t/data/models/priority.dart';
import 'package:t/data/models/task.dart';
import 'package:t/domain/repositories/task_repository.dart';

class TaskUseCases {
  final TaskRepository _repository;

  TaskUseCases(this._repository);

  Future<List<Task>> getAllTasks() => _repository.getAllTasks();

  Future<Task?> getTaskById(String id) => _repository.getTaskById(id);

  Future<void> addTask(Task task) => _repository.addTask(task);

  Future<void> updateTask(Task task) => _repository.updateTask(task);

  Future<void> deleteTask(String id) => _repository.deleteTask(id);

  List<Task> filterTasks(List<Task> tasks, Priority? priority, String filter) {
    var filtered = List<Task>.from(tasks);
    
    if (priority != null) {
      filtered = filtered.where((t) => t.priorityId == priority.id).toList();
    }
    
    switch (filter) {
      case 'Активные':
        filtered = filtered.where((t) => !t.isCompleted).toList();
        break;
      case 'Выполненные':
        filtered = filtered.where((t) => t.isCompleted).toList();
        break;
    }
    
    filtered.sort((a, b) {
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    
    return filtered;
  }
}