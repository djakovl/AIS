import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:t/core/constants/app_constants.dart';
import 'package:t/data/models/datasources/local_data_source.dart';
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/providers/task_provider.dart';
import 'package:t/data/models/task.dart';
import 'package:t/presentation/screens/tasks/add_task_screen.dart';
import 'package:t/presentation/screens/tasks/task_detail_screen.dart';
import 'package:t/presentation/widgets/task_tile.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _isInitialLoadDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_isInitialLoadDone) {
      _isInitialLoadDone = true;
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    if (taskProvider.tasks.isEmpty) {
      Future.microtask(() => taskProvider.loadTasks());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: SafeArea(
            child: Column(
              children: [
                _buildPrioritiesRow(taskProvider),
                _buildHeader(taskProvider),
                Expanded(
                  child: _buildTasksList(taskProvider, context),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openAddTaskPage(context, taskProvider),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildPrioritiesRow(TaskProvider taskProvider) {
   
    final allPriority = Priority(
      id: 0,
      name: 'Все',
      color: '#3498db',
      eisenhowerQuad: 0,
      orderIndex: 0,
      isDefault: true,
    );
    
   
    final filteredPriorities = LocalDataSource.priorities
        .where((p) => p.id != 5)
        .toList();
    
    final displayPriorities = [allPriority, ...filteredPriorities];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 45,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: displayPriorities.length,
          itemBuilder: (context, index) {
            final priority = displayPriorities[index];
            final isSelected = index == 0 
                ? taskProvider.selectedPriority == null
                : taskProvider.selectedPriority?.id == priority.id;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  taskProvider.setSelectedPriority(
                    index == 0 ? null : priority
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? priority.flutterColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? priority.flutterColor : priority.flutterColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    index == 0 ? 'Все' : priority.shortName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : priority.flutterColor,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(TaskProvider taskProvider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                taskProvider.selectedPriority != null 
                    ? taskProvider.selectedPriority!.displayName
                    : 'Все задачи',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: AppConstants.taskFilters.map((filter) {
              final isSelected = taskProvider.selectedFilter == filter;
              return InkWell(
                onTap: () => taskProvider.setSelectedFilter(filter),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList(TaskProvider taskProvider, BuildContext context) {
    final tasks = taskProvider.getFilteredTasks();

    // Показываем индикатор загрузки только если действительно идет загрузка
    if (taskProvider.isLoading && tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Нет задач',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => taskProvider.loadTasks(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => taskProvider.loadTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskTile(
              task: task,
              onTap: () => _openTaskDetail(context, task, taskProvider),
              onToggle: (value) => _toggleTaskCompletion(task, taskProvider),
              onDelete: () => _deleteTask(context, task, taskProvider),
            ),
          );
        },
      ),
    );
  }

  void _openTaskDetail(BuildContext context, Task task, TaskProvider taskProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task),
      ),
    ).then((updatedTask) {
      if (updatedTask != null) {
        if (updatedTask == 'delete') {
          taskProvider.loadTasks();
        } else {
          taskProvider.updateTask(updatedTask);
        }
      }
    });
  }

  void _openAddTaskPage(BuildContext context, TaskProvider taskProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(
          initialPriorityId: taskProvider.selectedPriority?.id,
        ),
      ),
    ).then((newTask) {
      if (newTask != null) {
        taskProvider.loadTasks();
      }
    });
  }

  void _toggleTaskCompletion(Task task, TaskProvider taskProvider) {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );
    taskProvider.updateTask(updatedTask);
  }

  void _deleteTask(BuildContext context, Task task, TaskProvider taskProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление задачи'),
        content: Text('Удалить задачу "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      taskProvider.deleteTask(task.id);
    }
  }
}