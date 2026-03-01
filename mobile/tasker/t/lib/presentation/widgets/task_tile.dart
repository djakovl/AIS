// lib/presentation/widgets/task_tile.dart
import 'package:flutter/material.dart';
import 'package:t/core/utils/date_formatter.dart';
import 'package:t/data/models/task.dart';
import 'package:t/presentation/widgets/priority_chip.dart';
import 'package:t/presentation/widgets/status_chip.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final Function(bool?) onToggle;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = task.priority?.flutterColor ?? Colors.grey;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 24,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (task.priority != null)
                            PriorityChip(priority: task.priority!),
                          
                          if (task.dueDate != null)
                            _buildDateChip(task.dueDate!),
                          
                          if (task.status != null)
                            StatusChip(status: task.status!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: task.isCompleted,
                    onChanged: onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: Colors.green,
                  ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        height: 32,
                        child: Text('Редактировать', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        height: 32,
                        child: const Text('Удалить', style: TextStyle(fontSize: 12, color: Colors.red)),
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    final isOverdue = date.isBefore(DateTime.now()) && !task.isCompleted;
    final color = isOverdue ? Colors.red : Colors.grey.shade600;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            DateFormatter.getRelativeDate(date),
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}