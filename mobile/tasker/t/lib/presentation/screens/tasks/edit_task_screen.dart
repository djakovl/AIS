import 'package:flutter/material.dart';
import 'package:t/core/services/task_api_service.dart';
import 'package:t/core/utils/date_formatter.dart';
import 'package:t/core/utils/validators.dart';
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/status.dart';
import 'package:t/data/models/task.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;
  final int? initialPriorityId;
  
  const EditTaskScreen({
    super.key,
    required this.task,
    this.initialPriorityId,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
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
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadReferences();
    _initializeTaskData();
  }

  void _initializeTaskData() {
    // Заполняем контроллеры существующими данными
    _titleController.text = widget.task.title;
    _descriptionController.text = widget.task.description ?? '';
    
    // Устанавливаем дату и время из существующей задачи
    if (widget.task.dueDate != null) {
      _selectedDate = widget.task.dueDate;
      _selectedTime = TimeOfDay.fromDateTime(widget.task.dueDate!);
    }
    
    // Добавляем слушатели для отслеживания изменений
    _titleController.addListener(_onDataChanged);
    _descriptionController.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadReferences() async {
    setState(() {
      _isLoadingReferences = true;
      _referencesError = null;
    });

    try {
      // Загружаем статусы и приоритеты параллельно
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
        
        // Выбираем статус из существующей задачи
        _selectedStatus = statuses.firstWhere(
          (s) => s.id == widget.task.statusId,
          orElse: () => statuses.first,
        );
        
        // Выбираем приоритет из существующей задачи
        _selectedPriority = priorities.firstWhere(
          (p) => p.id == widget.task.priorityId,
          orElse: () => priorities.first,
        );
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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _hasChanges = true;
      });
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

        // Собираем только измененные поля
        final Map<String, dynamic> updateData = {};
        
        if (_titleController.text != widget.task.title) {
          updateData['title'] = _titleController.text;
        }
        
        if (_descriptionController.text != (widget.task.description ?? '')) {
          updateData['description'] = _descriptionController.text.isEmpty ? null : _descriptionController.text;
        }
        
        if (_selectedStatus!.id != widget.task.statusId) {
          updateData['status_id'] = _selectedStatus!.id;
        }
        
        if (_selectedPriority!.id != widget.task.priorityId) {
          updateData['priority_id'] = _selectedPriority!.id;
        }
        
        final originalDueDate = widget.task.dueDate;
        if (dueDate != originalDueDate) {
          updateData['due_date'] = dueDate?.toUtc().toIso8601String().replaceFirst('+00:00', 'Z');
        }

        // Если нет изменений, просто возвращаемся
        if (updateData.isEmpty) {
          Navigator.pop(context);
          return;
        }

        print('📤 Обновление задачи ${widget.task.id}:');
        print('   status_id: ${_selectedStatus!.id} (${_selectedStatus!.name})');
        print('   priority_id: ${_selectedPriority!.id} (${_selectedPriority!.name})');
        print('   due_date: ${updateData['due_date']}');

        final updatedTask = await TaskApi.updateTask(widget.task.id, updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Задача успешно обновлена'),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          Navigator.pop(context, updatedTask);
        }
      } on ApiException catch (e) {
        print('❌ API Error: ${e.statusCode} - ${e.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
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
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Отменить изменения?'),
          content: const Text('У вас есть несохраненные изменения. Вы уверены, что хотите выйти?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ПРОДОЛЖИТЬ РЕДАКТИРОВАНИЕ'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Закрыть диалог
                Navigator.pop(context); // Закрыть экран редактирования
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('ВЫЙТИ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать задачу'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_hasChanges) {
              _showDiscardDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
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
              onPressed: _hasChanges ? _saveTask : null,
              child: Text(
                'СОХРАНИТЬ',
                style: TextStyle(
                  color: _hasChanges ? Colors.white : Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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
                          // Название и описание
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
                          
                          // Статус
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
                                        onTap: () {
                                          setState(() {
                                            _selectedStatus = status;
                                            _hasChanges = true;
                                          });
                                        },
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
                          
                          // Приоритет
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
                                        onTap: () {
                                          setState(() {
                                            _selectedPriority = priority;
                                            _hasChanges = true;
                                          });
                                        },
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
                          
                          // Срок выполнения
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Срок выполнения',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      if (_selectedDate != null)
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedDate = null;
                                              _selectedTime = null;
                                              _hasChanges = true;
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Очистить',
                                            style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                                          ),
                                        ),
                                    ],
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
                                                        : 'Не указана',
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
                                          onTap: _selectedDate != null ? () => _selectTime(context) : null,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              color: _selectedDate != null ? Colors.white : Colors.grey.shade100,
                                              border: Border.all(
                                                color: _selectedDate != null 
                                                    ? Colors.grey.shade300 
                                                    : Colors.grey.shade200,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time, 
                                                  size: 18, 
                                                  color: _selectedDate != null 
                                                      ? Colors.blue.shade400 
                                                      : Colors.grey.shade400,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _selectedTime != null && _selectedDate != null
                                                        ? DateFormatter.formatTime(_selectedTime!)
                                                        : 'Время',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: _selectedTime != null && _selectedDate != null
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
                              onPressed: (_hasChanges && !_isLoading) ? _saveTask : null,
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
                                      'СОХРАНИТЬ ИЗМЕНЕНИЯ',
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