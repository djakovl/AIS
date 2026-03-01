import 'package:flutter/material.dart';
import 'package:t/core/services/task_api_service.dart';
import 'package:t/core/utils/date_formatter.dart';
import 'package:t/core/utils/validators.dart';
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/status.dart';
import 'package:t/data/models/task.dart';

class AddTaskScreen extends StatefulWidget {
  final int? initialPriorityId;
  
  const AddTaskScreen({
    super.key,
    this.initialPriorityId,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Status> _statuses = [];
  List<Priority> _priorities = [];
  bool _isLoadingReferences = true;
  String? _referencesError;

  Priority? _selectedPriority;
  Status? _selectedStatus;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReferences();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _isLoadingReferences = true;
      _referencesError = null;
    });

    try {
      final results = await Future.wait([
        ReferenceApi.getStatuses(),
        ReferenceApi.getPriorities(),
      ]);

      final statuses = results[0] as List<Status>;
      final priorities = results[1] as List<Priority>;

      print('📥 Загружено статусов: ${statuses.length}');
      print('📥 Загружено приоритетов: ${priorities.length}');
      
      // Логируем для отладки
      for (var s in statuses) {
        print('   Статус: ${s.name} -> ID: ${s.id}');
      }
      for (var p in priorities) {
        print('   Приоритет: ${p.name} -> ID: ${p.id}');
      }

      setState(() {
        _statuses = statuses;
        _priorities = priorities;
        _isLoadingReferences = false;
        
        _selectedStatus = statuses.firstWhere(
          (s) => s.isDefault == true,
          orElse: () => statuses.first,
        );
        
        if (widget.initialPriorityId != null) {
          _selectedPriority = priorities.firstWhere(
            (p) => p.id == widget.initialPriorityId,
            orElse: () => priorities.firstWhere(
              (p) => p.isDefault == true,
              orElse: () => priorities.first,
            ),
          );
        } else {
         
          _selectedPriority = priorities.firstWhere(
            (p) => p.isDefault == true,
            orElse: () => priorities.first,
          );
        }
      });
    } catch (e) {
      print('❌ Ошибка загрузки справочников: $e');
      setState(() {
        _isLoadingReferences = false;
        _referencesError = 'Не удалось загрузить данные. Проверьте соединение.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

Future<void> _saveTask() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);

    try {
      DateTime? dueDate;
      if (_selectedDate != null && _selectedTime != null) {
        dueDate = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      final Map<String, dynamic> taskData = {
  'title': _titleController.text,
  'description': _descriptionController.text,
  'status_id': _selectedStatus!.id,  
  'priority_id': _selectedPriority!.id,  
  if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String().replaceFirst('+00:00', 'Z'),
};

      print('📤 Отправка задачи:');
      print('   status_id: ${_selectedStatus!.id} (${_selectedStatus!.name}) - тип: ${_selectedStatus!.id.runtimeType}');
      print('   priority_id: ${_selectedPriority!.id} (${_selectedPriority!.name}) - тип: ${_selectedPriority!.id.runtimeType}');
      print('   due_date: ${taskData['due_date']}');

      final createdTask = await TaskApi.createTask(taskData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Задача успешно создана'),
            backgroundColor: Colors.green.shade400,
          ),
        );
        Navigator.pop(context, createdTask);
      }
    } on ApiException catch (e) {
      print('❌ API Error: ${e.statusCode} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая задача'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (!_isLoadingReferences && _referencesError == null)
            TextButton(
              onPressed: _saveTask,
              child: const Text(
                'СОХРАНИТЬ',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: _isLoadingReferences
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Загрузка справочников...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            : _referencesError != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _referencesError!,
                          style: TextStyle(color: Colors.grey.shade700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReferences,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _titleController,
                                    validator: Validators.validateTaskTitle,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      labelText: 'Название задачи',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  TextFormField(
                                    controller: _descriptionController,
                                    maxLines: 5,
                                    style: const TextStyle(fontSize: 15, height: 1.4),
                                    decoration: InputDecoration(
                                      labelText: 'Описание',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      alignLabelWithHint: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText: 'Введите подробное описание задачи...',
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
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
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Статус',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _statuses.map((status) {
                                      final isSelected = _selectedStatus?.id == status.id;
                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedStatus = status),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? status.flutterColor : Colors.white,
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(
                                              color: isSelected ? status.flutterColor : status.flutterColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: status.flutterColor.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            status.name,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : status.flutterColor,
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
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
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Приоритет',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _priorities.map((priority) {
                                      final isSelected = _selectedPriority?.id == priority.id;
                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedPriority = priority),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? priority.flutterColor : Colors.white,
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(
                                              color: isSelected ? priority.flutterColor : priority.flutterColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: priority.flutterColor.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            priority.displayName,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : priority.flutterColor,
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
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
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Срок выполнения',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectDate(context),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.date_range, size: 18, color: Colors.blue.shade400),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _selectedDate != null
                                                        ? DateFormatter.formatDate(_selectedDate!)
                                                        : 'Выбрать дату',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: _selectedDate != null 
                                                          ? Colors.grey.shade800 
                                                          : Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectTime(context),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.access_time, size: 18, color: Colors.blue.shade400),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _selectedTime != null
                                                        ? DateFormatter.formatTime(_selectedTime!)
                                                        : 'Выбрать время',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: _selectedTime != null 
                                                          ? Colors.grey.shade800 
                                                          : Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveTask,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'СОЗДАТЬ ЗАДАЧУ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}