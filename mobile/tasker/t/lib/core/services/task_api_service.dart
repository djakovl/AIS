import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;
import 'package:t/data/models/priority.dart';
import 'package:t/data/models/status.dart';
import 'package:t/data/models/task.dart';
import 'package:t/data/models/task_dto.dart';
import 'dart:io';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class BaseRequest {
  static const String _tag = 'API';
  static const int _maxRedirects = 5;
  
  static String _formatData(dynamic data) {
    if (data == null) return 'null';
    try {
      if (data is Map || data is List) {
        return JsonEncoder.withIndent('  ').convert(data);
      }
      return data.toString();
    } catch (e) {
      return 'Error formatting data: $e';
    }
  }
  
  static Future<Map<String, String>> _getHeaders() async {
    final storage = SecureStorage();
    final sessionId = await storage.getSessionId();
    final userId = await storage.getUserId();
    final token = await storage.getToken();
    final csrfToken = await storage.getCsrfToken();
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (sessionId != null) 'Cookie': 'session_id=$sessionId',
      if (userId != null) 'X-User-Id': userId,
      if (token != null) 'Authorization': 'Bearer $token',
      if (csrfToken != null) 'X-CSRF-Token': csrfToken,
    };
    
    return headers;
  }

  static Future<http.Response> _requestWithRedirect(
    Future<http.Response> Function() requestFn,
    String url,
    String method,
    int redirectCount,
  ) async {
    try {
      final response = await requestFn();
      
      if ((response.statusCode == 307 || 
           response.statusCode == 308 || 
           response.statusCode == 301 || 
           response.statusCode == 302) && 
          redirectCount < _maxRedirects) {
        
        final location = response.headers['location'];
        if (location != null) {
          final newUri = Uri.parse(location);
          final newUrl = newUri.toString();
          
          return _requestWithRedirect(
            () async {
              final client = _createHttpClient();
              try {
                if (method == 'GET') {
                  return await client.get(newUri, headers: await _getHeaders());
                } else if (method == 'POST') {
                  return await client.post(newUri, headers: await _getHeaders(), body: '');
                } else if (method == 'PUT') {
                  return await client.put(newUri, headers: await _getHeaders(), body: '');
                } else if (method == 'DELETE') {
                  return await client.delete(newUri, headers: await _getHeaders());
                }
                throw Exception('Unsupported method for redirect: $method');
              } finally {
                client.close();
              }
            },
            newUrl,
            method,
            redirectCount + 1,
          );
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> get(String url, {Map<String, String>? params}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$url').replace(
      queryParameters: params,
    );
    
    final startTime = DateTime.now();
    final headers = await _getHeaders();
    
    try {
      final response = await _requestWithRedirect(
        () async {
          final client = _createHttpClient();
          try {
            return await client.get(uri, headers: headers).timeout(
              const Duration(seconds: 10),
            );
          } finally {
            client.close();
          }
        },
        uri.toString(),
        'GET',
        0,
      );
      
      final duration = DateTime.now().difference(startTime);
      return _handleResponse(response, duration, url, requestData: null, method: 'GET');
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      await _handleRequestError(e, stackTrace, uri.toString(), duration, 'GET');
      rethrow;
    }
  }

  static Future<dynamic> post(String url, {dynamic data}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$url');
    
    final startTime = DateTime.now();
    final headers = await _getHeaders();
    
    try {
      final encodedBody = data != null ? jsonEncode(data) : '';
      
      final response = await _requestWithRedirect(
        () async {
          final client = _createHttpClient();
          try {
            return await client.post(
              uri,
              headers: headers,
              body: encodedBody,
            ).timeout(const Duration(seconds: 10));
          } finally {
            client.close();
          }
        },
        uri.toString(),
        'POST',
        0,
      );
      
      final duration = DateTime.now().difference(startTime);
      return _handleResponse(response, duration, url, requestData: data, method: 'POST');
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      await _handleRequestError(e, stackTrace, uri.toString(), duration, 'POST');
      rethrow;
    }
  }

  static Future<dynamic> put(String url, {dynamic data}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$url');
    
    final startTime = DateTime.now();
    final headers = await _getHeaders();
    
    try {
      final encodedBody = data != null ? jsonEncode(data) : '';
      
      final response = await _requestWithRedirect(
        () async {
          final client = _createHttpClient();
          try {
            return await client.put(
              uri,
              headers: headers,
              body: encodedBody,
            ).timeout(const Duration(seconds: 10));
          } finally {
            client.close();
          }
        },
        uri.toString(),
        'PUT',
        0,
      );
      
      final duration = DateTime.now().difference(startTime);
      return _handleResponse(response, duration, url, requestData: data, method: 'PUT');
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      await _handleRequestError(e, stackTrace, uri.toString(), duration, 'PUT');
      rethrow;
    }
  }

  static Future<dynamic> delete(String url) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$url');
    
    final startTime = DateTime.now();
    final headers = await _getHeaders();
    
    try {
      final response = await _requestWithRedirect(
        () async {
          final client = _createHttpClient();
          try {
            return await client.delete(uri, headers: headers).timeout(
              const Duration(seconds: 10),
            );
          } finally {
            client.close();
          }
        },
        uri.toString(),
        'DELETE',
        0,
      );
      
      final duration = DateTime.now().difference(startTime);
      return _handleResponse(response, duration, url, requestData: null, method: 'DELETE');
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      await _handleRequestError(e, stackTrace, uri.toString(), duration, 'DELETE');
      rethrow;
    }
  }

  static Future<void> _handleRequestError(
    dynamic error,
    StackTrace stackTrace,
    String url,
    Duration duration,
    String method,
  ) async {
    if (error is ApiException) {
      throw error;
    }
    if (error is SocketException) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: ${error.message}',
      );
    }
    if (error is TimeoutException) {
      throw ApiException(
        statusCode: 0,
        message: 'Request timeout after 10 seconds',
      );
    }
    if (error is FormatException) {
      throw ApiException(
        statusCode: 0,
        message: 'Data format error: ${error.message}',
      );
    }
    throw ApiException(
      statusCode: 0,
      message: error.toString(),
    );
  }

  static dynamic _handleResponse(
    http.Response response, 
    Duration duration, 
    String url, {
    dynamic requestData,
    required String method,
  }) {
    final statusCode = response.statusCode;
    final body = response.body;
    
    dynamic parsedBody;
    try {
      parsedBody = jsonDecode(body);
    } catch (e) {
      parsedBody = body;
    }
    
    final isSuccess = statusCode >= 200 && statusCode < 300;

    if (isSuccess) {
      return parsedBody;
    } else {
      String errorMessage;
      if (parsedBody is Map) {
        errorMessage = (parsedBody as Map)['message'] ?? 
                       (parsedBody as Map)['error'] ?? 
                       'HTTP Error $statusCode';
      } else {
        errorMessage = 'HTTP Error $statusCode';
      }
      
      throw ApiException(
        statusCode: statusCode,
        message: errorMessage,
        data: parsedBody,
      );
    }
  }

  static http.Client _createHttpClient() {
    final HttpClient httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return http.IOClient(httpClient);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;
  
  ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });
  
  @override
  String toString() {
    return 'ApiException: $statusCode - $message';
  }
}


class TaskApi {
  static const String _tag = 'TaskApi';
  
  static String _formatData(dynamic data) {
    if (data == null) return 'null';
    try {
      if (data is Map || data is List) {
        return JsonEncoder.withIndent('  ').convert(data);
      }
      return data.toString();
    } catch (e) {
      return 'Error formatting data: $e';
    }
  }

  static Status _mapTaskStatus(int statusId) {
    const Map<int, String> statusRussianNames = {
      1: 'Новая',
      2: 'В процессе',
      3: 'Выполнена',
      4: 'Отменена',
    };

    const Map<int, String> statusColors = {
      1: '#3498db',
      2: '#f39c12',
      3: '#27ae60',
      4: '#e74c3c',
    };

    return Status(
      id: statusId,
      name: statusRussianNames[statusId] ?? 'Неизвестно',
      color: statusColors[statusId] ?? '#95a5a6',
      orderIndex: statusId,
      isDefault: statusId == 1,
    );
  }

  static Priority _mapTaskPriority(int priorityId) {
    const Map<int, String> priorityRussianNames = {
      1: 'Низкий',
      2: 'Средний',
      3: 'Высокий',
      4: 'Критический',
    };

    const Map<int, String> priorityColors = {
      1: '#2ecc71',
      2: '#f1c40f',
      3: '#f39c12',
      4: '#e74c3c',
    };

    const Map<int, int> priorityEisenhowerQuad = {
      1: 3,
      2: 2,
      3: 1,
      4: 1,
    };

    const Map<int, int> priorityOrderIndex = {
      1: 4,
      2: 3,
      3: 2,
      4: 1,
    };

    return Priority(
      id: priorityId,
      name: priorityRussianNames[priorityId] ?? 'Неизвестно',
      color: priorityColors[priorityId] ?? '#95a5a6',
      eisenhowerQuad: priorityEisenhowerQuad[priorityId] ?? 4,
      orderIndex: priorityOrderIndex[priorityId] ?? 999,
      isDefault: priorityId == 4,
    );
  }

  static Future<List<Task>> listTasks({TaskFilter? params}) async {
    final endpoint = '/tasks';
    final queryParams = params?.toQueryParams();
    
    try {
      final response = await BaseRequest.get(
        endpoint,
        params: queryParams,
      );
      
      final List<dynamic> data = [];
      if (response is Map && response['data'] != null) {
        final responseData = response['data'];
        if (responseData is List) {
          data.addAll(responseData);
        }
      }

      final List<Task> tasks = [];
      for (var json in data) {
        try {
          final task = Task.fromJson({'data': json});
          
          int statusId = 1;
          if (json['status'] != null && json['status'] is Map) {
            statusId = json['status']['id'] as int? ?? 1;
          }
          
          int priorityId = 2;
          if (json['priority'] != null && json['priority'] is Map) {
            priorityId = json['priority']['id'] as int? ?? 2;
          }
          
          final updatedTask = Task(
            id: task.id,
            title: task.title,
            description: task.description,
            statusId: statusId.toString(),
            priorityId: priorityId.toString(),
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            orderIndex: task.orderIndex,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            completedAt: task.completedAt,
          );
          
          updatedTask.status = _mapTaskStatus(statusId);
          updatedTask.priority = _mapTaskPriority(priorityId);
          
          tasks.add(updatedTask);
        } catch (e) {
          developer.log('Error processing task: $e');
        }
      }
      
      return tasks;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  static Future<Task> getTask(String id) async {
    final endpoint = '/tasks/$id';
    
    try {
      final response = await BaseRequest.get(endpoint);
      
      Map<String, dynamic> taskJson = {};
      if (response is Map && response['data'] != null) {
        final data = response['data'];
        if (data is Map) {
          taskJson = Map<String, dynamic>.from(data);
        }
      }
      
      final originalTask = Task.fromJson({'data': taskJson});
      
      int statusId = 1;
      if (taskJson['status'] != null && taskJson['status'] is Map) {
        statusId = taskJson['status']['id'] as int? ?? 1;
      }
      
      int priorityId = 2;
      if (taskJson['priority'] != null && taskJson['priority'] is Map) {
        priorityId = taskJson['priority']['id'] as int? ?? 2;
      }
      
      final task = Task(
        id: originalTask.id,
        title: originalTask.title,
        description: originalTask.description,
        statusId: statusId.toString(),
        priorityId: priorityId.toString(),
        dueDate: originalTask.dueDate,
        isCompleted: originalTask.isCompleted,
        orderIndex: originalTask.orderIndex,
        createdAt: originalTask.createdAt,
        updatedAt: originalTask.updatedAt,
        completedAt: originalTask.completedAt,
      );
      
      task.status = _mapTaskStatus(statusId);
      task.priority = _mapTaskPriority(priorityId);
      
      return task;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  static Future<Task> createTask(Map<String, dynamic> data) async {
    final endpoint = '/tasks';
    
    try {
      final response = await BaseRequest.post(endpoint, data: data);
      
      Map<String, dynamic> taskJson = {};
      if (response is Map && response['data'] != null) {
        final responseData = response['data'];
        if (responseData is Map) {
          taskJson = Map<String, dynamic>.from(responseData);
        }
      }
      
      final task = Task.fromJson({'data': taskJson});
      
      final statusId = int.tryParse(task.statusId.toString()) ?? 1;
      final priorityId = int.tryParse(task.priorityId.toString()) ?? 1;
      
      task.status = _mapTaskStatus(statusId);
      task.priority = _mapTaskPriority(priorityId);
      
      return task;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  static Future<Task> updateTask(String id, Map<String, dynamic> data) async {
    final endpoint = '/tasks/$id';
    
    try {
      final response = await BaseRequest.put(endpoint, data: data);
      
      Map<String, dynamic> taskJson = {};
      if (response is Map && response['data'] != null) {
        final responseData = response['data'];
        if (responseData is Map) {
          taskJson = Map<String, dynamic>.from(responseData);
        }
      }
      
      final originalTask = Task.fromJson({'data': taskJson});
      
      int statusId = 1;
      if (taskJson['status'] != null && taskJson['status'] is Map) {
        statusId = taskJson['status']['id'] as int? ?? 1;
      }
      
      int priorityId = 2;
      if (taskJson['priority'] != null && taskJson['priority'] is Map) {
        priorityId = taskJson['priority']['id'] as int? ?? 2;
      }
      
      final task = Task(
        id: originalTask.id,
        title: originalTask.title,
        description: originalTask.description,
        statusId: statusId.toString(),
        priorityId: priorityId.toString(),
        dueDate: originalTask.dueDate,
        isCompleted: originalTask.isCompleted,
        orderIndex: originalTask.orderIndex,
        createdAt: originalTask.createdAt,
        updatedAt: originalTask.updatedAt,
        completedAt: originalTask.completedAt,
      );
      
      task.status = _mapTaskStatus(statusId);
      task.priority = _mapTaskPriority(priorityId);
      
      return task;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  static Future<void> deleteTask(String id) async {
    final endpoint = '/tasks/$id';
    
    try {
      await BaseRequest.delete(endpoint);
    } catch (e, stackTrace) {
      rethrow;
    }
  }
}

class ReferenceApi {
  static const String _tag = 'ReferenceApi';
  
  static String _formatData(dynamic data) {
    if (data == null) return 'null';
    try {
      if (data is Map || data is List) {
        return JsonEncoder.withIndent('  ').convert(data);
      }
      return data.toString();
    } catch (e) {
      return 'Error formatting data: $e';
    }
  }
  
  static const Map<String, String> _statusRussianNames = {
    'pending': 'Новая',
    'in_progress': 'В процессе',
    'completed': 'Выполнена',
    'cancelled': 'Отменена',
  };
  
  static const Map<String, String> _statusColors = {
    'pending': '#3498db',
    'in_progress': '#f39c12',
    'completed': '#27ae60',
    'cancelled': '#e74c3c',
  };

  static const Map<String, String> _priorityRussianNames = {
    'low': 'Низкий',
    'medium': 'Средний',
    'high': 'Высокий',
    'urgent': 'Критический',
  };

  static const Map<String, String> _priorityColors = {
    'low': '#2ecc71',
    'medium': '#f1c40f',
    'high': '#f39c12',
    'urgent': '#e74c3c',
  };

  static Future<List<Status>> getStatuses() async {
    final endpoint = '/tasks/statuses';
    
    try {
      final response = await BaseRequest.get(endpoint);
      
      final List<dynamic> data = [];
      if (response is Map && response['data'] != null) {
        final responseData = response['data'];
        if (responseData is List) {
          data.addAll(responseData);
        }
      }
      
      final List<Status> statuses = [];
      for (var json in data) {
        final serverName = json['name'] as String;
        final serverId = json['id'] as int;
        
        final russianName = _statusRussianNames[serverName] ?? 
            _capitalizeFirst(serverName.replaceAll('_', ' '));
        
        final color = json['color'] ?? _statusColors[serverName] ?? '#95a5a6';
        
        int orderIndex;
        bool isDefault;
        
        switch(serverName) {
          case 'pending':
            orderIndex = 1;
            isDefault = true;
            break;
          case 'in_progress':
            orderIndex = 2;
            isDefault = false;
            break;
          case 'completed':
            orderIndex = 3;
            isDefault = false;
            break;
          case 'cancelled':
            orderIndex = 4;
            isDefault = false;
            break;
          default:
            orderIndex = json['order_index'] ?? 999;
            isDefault = json['is_default'] ?? false;
        }
        
        statuses.add(Status(
          id: serverId,
          name: russianName,
          color: color,
          orderIndex: orderIndex,
          isDefault: isDefault,
        ));
      }
      
      return statuses;
    } catch (e, stackTrace) {
      rethrow;
    }
  }
  
  static Future<List<Priority>> getPriorities() async {
    final endpoint = '/tasks/priorities';
    
    try {
      final response = await BaseRequest.get(endpoint);
      
      final List<dynamic> data = [];
      if (response is Map && response['data'] != null) {
        final responseData = response['data'];
        if (responseData is List) {
          data.addAll(responseData);
        }
      }
      
      final List<Priority> priorities = [];
      for (var json in data) {
        final serverName = json['name'] as String;
        final serverId = json['id'] as int;
        
        final russianName = _priorityRussianNames[serverName] ?? 
            _capitalizeFirst(serverName);
        
        final color = json['color'] ?? _priorityColors[serverName] ?? '#95a5a6';
        
        int eisenhowerQuad;
        switch(serverName) {
          case 'urgent':
          case 'high':
            eisenhowerQuad = 1;
            break;
          case 'medium':
            eisenhowerQuad = 2;
            break;
          case 'low':
            eisenhowerQuad = 3;
            break;
          default:
            eisenhowerQuad = 4;
        }
        
        int orderIndex;
        bool isDefault;
        
        switch(serverName) {
          case 'urgent':
            orderIndex = 1;
            isDefault = true;
            break;
          case 'high':
            orderIndex = 2;
            isDefault = false;
            break;
          case 'medium':
            orderIndex = 3;
            isDefault = false;
            break;
          case 'low':
            orderIndex = 4;
            isDefault = false;
            break;
          default:
            orderIndex = json['order_index'] ?? 999;
            isDefault = json['is_default'] ?? false;
        }
        
        priorities.add(Priority(
          id: serverId,
          name: russianName,
          color: color,
          eisenhowerQuad: eisenhowerQuad,
          orderIndex: orderIndex,
          isDefault: isDefault,
        ));
      }
      
      return priorities;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}