// lib/data/models/task_dto.dart
class TaskFilter {
  final String? statusId;
  final String? priorityId;
  final String? parentTaskId;
  final String? search;
  final bool? isCompleted;
  final DateTime? dueBefore;
  final DateTime? dueAfter;
  final int page;
  final int limit;

  TaskFilter({
    this.statusId,
    this.priorityId,
    this.parentTaskId,
    this.search,
    this.isCompleted,
    this.dueBefore,
    this.dueAfter,
    this.page = 1,
    this.limit = 20,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    
    if (statusId != null) params['status_id'] = statusId!;
    if (priorityId != null) params['priority_id'] = priorityId!;
    if (parentTaskId != null) params['parent_task_id'] = parentTaskId!;
    if (search != null) params['search'] = search!;
    if (isCompleted != null) params['is_completed'] = isCompleted!.toString();
    if (dueBefore != null) params['due_before'] = dueBefore!.toIso8601String();
    if (dueAfter != null) params['due_after'] = dueAfter!.toIso8601String();
    
    params['page'] = page.toString();
    params['limit'] = limit.toString();
    
    return params;
  }
}