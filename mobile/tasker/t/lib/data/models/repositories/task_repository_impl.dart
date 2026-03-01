import 'package:t/data/models/task.dart';
import 'package:t/domain/repositories/task_repository.dart';
import '../datasources/local_data_source.dart';


class TaskRepositoryImpl implements TaskRepository {
  final LocalDataSource _localDataSource;

  TaskRepositoryImpl(this._localDataSource);

  @override
  Future<List<Task>> getAllTasks() async {
    return await _localDataSource.getTasks();
  }

  @override
  Future<Task?> getTaskById(String id) async {
    return await _localDataSource.getTaskById(id);
  }

  @override
  Future<void> addTask(Task task) async {
    await _localDataSource.addTask(task);
  }

  @override
  Future<void> updateTask(Task task) async {
    await _localDataSource.updateTask(task);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _localDataSource.deleteTask(id);
  }
}