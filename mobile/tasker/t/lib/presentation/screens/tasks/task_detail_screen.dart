import 'package:flutter/material.dart';
import 'package:t/core/utils/date_formatter.dart';
import 'package:t/data/models/datasources/local_data_source.dart';
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/status.dart';
import 'package:t/data/models/task.dart';
import 'package:t/core/services/task_api_service.dart';
import 'package:t/presentation/screens/tasks/edit_task_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  
  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;
  bool _isLoading = false;

  static const int _pendingStatusId = 1;
  static const int _inProgressStatusId = 2;
  static const int _completedStatusId = 3;
  static const int _cancelledStatusId = 4;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _updateTask(Map<String, dynamic> updateData) async {
    setState(() => _isLoading = true);

    try {
      final updatedTask = await TaskApi.updateTask(_task.id, updateData);
      
      if (mounted) {
        setState(() {
          _task = updatedTask;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Задача обновлена'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getStatusServerName(int statusId) {
    switch(statusId) {
      case 1: return 'pending';
      case 2: return 'in_progress';
      case 3: return 'completed';
      case 4: return 'cancelled';
      default: return 'pending';
    }
  }

  String _getPriorityServerName(int priorityId) {
    switch(priorityId) {
      case 1: return 'low';
      case 2: return 'medium';
      case 3: return 'high';
      case 4: return 'urgent';
      default: return 'medium';
    }
  }

  int _getPriorityLevel(int priorityId) {
    switch(priorityId) {
      case 1: return 1;
      case 2: return 2;
      case 3: return 3;
      case 4: return 4;
      default: return 2;
    }
  }

  String _getStatusName(int statusId) {
    switch(statusId) {
      case 1: return 'Новая';
      case 2: return 'В процессе';
      case 3: return 'Выполнена';
      case 4: return 'Отменена';
      default: return 'Неизвестно';
    }
  }

  String _getPriorityName(int priorityId) {
    switch(priorityId) {
      case 1: return 'Низкий';
      case 2: return 'Средний';
      case 3: return 'Высокий';
      case 4: return 'Критический';
      default: return 'Неизвестно';
    }
  }

  Color _getPriorityColor(int priorityId) {
    switch(priorityId) {
      case 1: return Colors.green;
      case 2: return Colors.amber;
      case 3: return Colors.orange;
      case 4: return Colors.red;
      default: return Colors.blue;
    }
  }

  Color _getStatusColor(int statusId) {
    switch(statusId) {
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.green;
      case 4: return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Удалить задачу "${_task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        await TaskApi.deleteTask(_task.id);
        
        if (mounted) {
          Navigator.pop(context, 'delete');
        }
      } on ApiException catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _changeStatus() async {
    final selected = await showDialog<Status>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Выберите статус'),
        children: LocalDataSource.statuses.map((status) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, status),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: status.flutterColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(status.name),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
    
    if (selected != null) {
      final selectedId = int.tryParse(selected.id.toString()) ?? 1;
      final currentId = int.tryParse(_task.statusId.toString()) ?? 1;
      
      if (selectedId != currentId) {
        final isCompleted = selectedId == _completedStatusId;
        
        await _updateTask({
          'status_id': selectedId,
          'is_completed': isCompleted,
          if (isCompleted) 'completed_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  void _changePriority() async {
    final selected = await showDialog<Priority>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Выберите приоритет'),
        children: LocalDataSource.priorities.map((priority) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, priority),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: priority.flutterColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(priority.displayName),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
    
    if (selected != null) {
      final selectedId = int.tryParse(selected.id.toString()) ?? 1;
      final currentId = int.tryParse(_task.priorityId.toString()) ?? 1;
      
      if (selectedId != currentId) {
        await _updateTask({'priority_id': selectedId});
      }
    }
  }

  void _toggleComplete() {
    final currentStatusId = int.tryParse(_task.statusId.toString()) ?? 1;
    
    if (!_task.isCompleted) {
      _updateTask({
        'is_completed': true,
        'status_id': _completedStatusId,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } else {
      _updateTask({
        'is_completed': false,
        'status_id': _pendingStatusId,
        'completed_at': null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusId = int.tryParse(_task.statusId.toString()) ?? 1;
    final priorityId = int.tryParse(_task.priorityId.toString()) ?? 1;
    
    final priorityColor = _getPriorityColor(priorityId);
    final statusColor = _getStatusColor(statusId);
    final statusName = _getStatusName(statusId);
    final priorityName = _getPriorityName(priorityId);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: priorityColor,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context, _task),
                ),
                actions: [
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Удалить', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditTaskScreen(task: _task),
                          ),
                        );
                        
                        if (result != null && result is Task) {
                          setState(() {
                            _task = result;
                          });
                        }
                      } else if (value == 'delete') {
                        _deleteTask();
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    _task.title,
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center, 
                  ),
                  centerTitle: true, 
                  titlePadding: const EdgeInsets.only(bottom: 16), 
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          priorityColor,
                          priorityColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _changeStatus,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Статус',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              statusName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: statusColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            size: 16,
                                            color: statusColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            Container(width: 1, height: 30, color: Colors.grey[300]),
                            
                            Expanded(
                              child: GestureDetector(
                                onTap: _changePriority,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Приоритет',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: priorityColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: priorityColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              priorityName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: priorityColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            size: 16,
                                            color: priorityColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_task.description?.isNotEmpty == true)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description, size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Описание',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _task.description!,
                                style: const TextStyle(fontSize: 15, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                const Text(
                                  'Детали',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            _buildDetailRow(
                              'Создана', 
                              DateFormatter.formatDateTime(_task.createdAt),
                              Icons.access_time,
                            ),
                            
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            
                            _buildDetailRow(
                              'Срок', 
                              _task.dueDate != null 
                                  ? DateFormatter.formatDateTime(_task.dueDate!) 
                                  : 'Не указан',
                              Icons.event,
                              color: _task.dueDate != null && 
                                     _task.dueDate!.isBefore(DateTime.now()) && 
                                     !_task.isCompleted 
                                  ? Colors.red 
                                  : null,
                            ),
                            
                            if (_task.completedAt != null) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                              _buildDetailRow(
                                'Завершена', 
                                DateFormatter.formatDateTime(_task.completedAt!),
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _toggleComplete,
        backgroundColor: _task.isCompleted ? Colors.orange : Colors.green,
        icon: Icon(_task.isCompleted ? Icons.undo : Icons.check),
        label: Text(_task.isCompleted ? 'Возобновить' : 'Завершить'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoBlock({
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: color ?? Colors.black87,
                    fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}