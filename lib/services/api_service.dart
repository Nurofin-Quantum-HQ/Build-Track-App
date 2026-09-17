import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/config/api_config.dart';
import 'package:flutter/foundation.dart';

import 'dart:math';
import 'package:buildtrack_mobile/services/auth_service.dart';

class ApiService {
  static List<ProjectModel>? mockProjects;
  static String get baseUrl => ApiConfig.baseUrl;

  static String _generateRequestId() {
    final random = Random();
    String hex(int max) => random.nextInt(max).toRadixString(16).padLeft(2, '0');
    return 'BT-${DateTime.now().toIso8601String().replaceAll(RegExp(r'[-:T.]'), '').substring(0, 14)}-'
           '${hex(256)}${hex(256)}${hex(256)}';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken(); // [BT-SEC-05] single source of truth
    return {
      'Content-Type': 'application/json',
      'X-Request-ID': _generateRequestId(),
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      AuthService.logout(sessionExpired: true);
      throw Exception('Unauthorized');
    }
  }

  // --- OFFLINE SYNC LOGIC ---
  static const String _offlineQueueKey = 'offline_post_queue';

  static Future<void> _queueOfflineRequest(String endpoint, Map<String, dynamic> body, {String method = 'POST'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString(_offlineQueueKey) ?? '[]';
      final queue = List<Map<String, dynamic>>.from(jsonDecode(queueStr));
      queue.add({
        'endpoint': endpoint,
        'body': body,
        'method': method,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_offlineQueueKey, jsonEncode(queue));
      if (kDebugMode) debugPrint('Queued offline $method request to $endpoint');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to queue offline request: $e');
    }
  }

  static Future<void> syncOfflineEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString(_offlineQueueKey);
      if (queueStr == null || queueStr == '[]') return;

      final queue = List<Map<String, dynamic>>.from(jsonDecode(queueStr));
      if (queue.isEmpty) return;

      if (kDebugMode) debugPrint('Syncing ${queue.length} offline entries...');
      final List<Map<String, dynamic>> remainingQueue = [];
      final headers = await _getHeaders();

      for (var req in queue) {
        try {
          final url = '$baseUrl${req['endpoint']}';
          final method = req['method'] as String? ?? 'POST';
          http.Response response;
          if (method == 'PUT') {
            response = await http
                .put(Uri.parse(url), headers: headers, body: jsonEncode(req['body']))
                .timeout(const Duration(seconds: 30));
          } else {
            response = await http
                .post(Uri.parse(url), headers: headers, body: jsonEncode(req['body']))
                .timeout(const Duration(seconds: 30));
          }
          if (response.statusCode >= 200 && response.statusCode < 300) {
            if (kDebugMode) debugPrint('Synced: ${req['endpoint']}');
          } else {
            remainingQueue.add(req);
          }
        } catch (e) {
          remainingQueue.add(req);
        }
      }
      await prefs.setString(_offlineQueueKey, jsonEncode(remainingQueue));
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to sync offline entries: $e');
    }
  }

  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final url = '$baseUrl$endpoint';
    debugPrint('API Request [GET]: $url');
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 90));
    
    _checkUnauthorized(response);

    // Opportunistically sync
    syncOfflineEntries();
    
    return response;
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = await _getHeaders();
    final url = '$baseUrl$endpoint';
    debugPrint('API Request [POST]: $url');
    
    try {
      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
      debugPrint('Status: ${response.statusCode}');
      
      _checkUnauthorized(response);

      // Opportunistically sync
      syncOfflineEntries();
      
      return response;
      } catch (e) {
        if (e.toString() == 'Exception: Unauthorized') rethrow;
        debugPrint('Network/API error caught: $e. Queuing request for offline sync.');
        await _queueOfflineRequest(endpoint, body, method: 'POST');
        return http.Response(jsonEncode({'message': 'Queued for offline sync', 'offline': true}), 201);
      }
  }
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = await _getHeaders();
    final url = '$baseUrl$endpoint';
    debugPrint('API Request [PUT]: $url');
    debugPrint('Payload: ${jsonEncode(body)}');
    try {
      final response = await http
          .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      
      _checkUnauthorized(response);

      // Opportunistically sync
      syncOfflineEntries();
      
      return response;
    } catch (e) {
      if (e.toString() == 'Exception: Unauthorized') rethrow;
      debugPrint('Network/API error caught: $e. Queuing request for offline sync.');
      await _queueOfflineRequest(endpoint, body, method: 'PUT');
      return http.Response(jsonEncode({'message': 'Queued for offline sync', 'offline': true}), 200);
    }
  }
  static Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    final url = '$baseUrl$endpoint';
    debugPrint('API Request [DELETE]: $url');
    final response = await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 90));
    debugPrint('Status: ${response.statusCode}');
    debugPrint('Body: ${response.body}');

    _checkUnauthorized(response);

    return response;
  }
  static Future<List<ProjectModel>> fetchProjects() async {
    if (mockProjects != null) return mockProjects!;
    try {
      final response = await get('/projects');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> rawList = [];
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          rawList = decoded['projects'] ?? decoded['data'] ?? [];
        }
        List<ProjectModel> validProjects = [];
        for (var item in rawList) {
          try {
            validProjects.add(
              ProjectModel.fromJson(item as Map<String, dynamic>),
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('CRASH parsing project ${item['_id']}: $e');
            }
          }
        }
        return validProjects;
      } else if (response.statusCode == 401) {
        if (kDebugMode) {
          debugPrint('AUTH Error: Token missing (401).');
        }
        throw Exception('Unauthorized');
      } else {
        if (kDebugMode) {
          debugPrint('GET /projects failed: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('fetchProjects Master Error: $e');
      }
      return [];
    }
  }
  static Future<ProjectModel?> addProject(Map<String, dynamic> payload) async {
    try {
      final response = await post('/projects', payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        final Map<String, dynamic> projectJson =
            (decoded is Map && decoded.containsKey('project'))
            ? decoded['project'] as Map<String, dynamic>
            : decoded as Map<String, dynamic>;
        return ProjectModel.fromJson(projectJson);
      } else {
        if (kDebugMode) {
          debugPrint(
            'POST /projects failed (${response.statusCode}): ${response.body}',
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('addProject Error: $e');
      }
      return null;
    }
  }
  static Future<ProjectModel?> fetchProjectById(String id) async {
    try {
      final response = await get('/projects/$id');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final Map<String, dynamic> projectJson =
            (decoded is Map && decoded.containsKey('project'))
            ? decoded['project'] as Map<String, dynamic>
            : decoded as Map<String, dynamic>;
        return ProjectModel.fromJson(projectJson);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('fetchProjectById error: $e');
      }
      return null;
    }
  }
  static Future<List<dynamic>> fetchMaterials({String? projectId}) async {
    try {
      String endpoint = '/transactions?filterByViewAccess=true&limit=10000';
      if (projectId != null && projectId.isNotEmpty && projectId != 'all') {
        endpoint += '&project=$projectId';
      }
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map) {
          return decoded['transactions'] ?? decoded['data'] ?? [];
        }
        return [];
      } else if (response.statusCode == 401) {
        if (kDebugMode) {
          debugPrint(
            'AUTH Error: Token missing or expired (401). Body: ${response.body}',
          );
        }
        throw Exception('Unauthorized – please log in again');
      } else {
        if (kDebugMode) {
          debugPrint(
            'GET /transactions failed with status ${response.statusCode}: ${response.body}',
          );
        }
        throw Exception(
          'Failed to load transactions (HTTP ${response.statusCode})',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GET Error: $e');
      }
      return [];
    }
  }
  static Future<bool> addMaterial(Map<String, dynamic> payload) async {
    try {
      final response = await post('/transactions', payload);
      if (kDebugMode) {
        debugPrint('=== SERVER RESPONSE DEBUG ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('=============================');
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('POST Error: $e');
      }
      return false;
    }
  }
  static Future<Map<String, dynamic>?> addTransactionsBulk(
    List<Map<String, dynamic>> payloads,
  ) async {
    try {
      final response = await post('/transactions/bulk', {
        'transactions': payloads,
      });
      if (kDebugMode) {
        debugPrint('=== BULK UPLOAD SERVER RESPONSE ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('===================================');
      }
      if (response.statusCode == 207 ||
          response.statusCode == 200 ||
          response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BULK POST Error: $e');
      }
      return null;
    }
  }
  static Future<Map<String, dynamic>?> addTransaction(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await post('/transactions', payload);
      if (kDebugMode) {
        debugPrint('=== SERVER RESPONSE DEBUG ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('=============================');
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('POST Error: $e');
      }
      return null;
    }
  }
  static Future<http.Response> updateTransactionPayment(
    String id,
    Map<String, dynamic> payload,
  ) async {
    // Return response directly so caller can distinguish status codes
    return await put('/transactions/$id', payload);
  }
  static Future<bool> updateTransaction(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await put('/transactions/$id', payload);
      if (kDebugMode) {
        debugPrint('=== PUT UPDATE TRANSACTION RESPONSE ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PUT /transactions/$id Error: $e');
      }
      return false;
    }
  }
  static Future<bool> deleteTransaction(String id) async {
    try {
      final response = await delete('/transactions/$id');
      if (kDebugMode) {
        debugPrint('=== DELETE TRANSACTION RESPONSE ===');
        debugPrint('Status Code: ${response.statusCode}');
      }
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DELETE /transactions/$id Error: $e');
      }
      return false;
    }
  }
  static Future<bool> deleteProject(String id) async {
    try {
      final response = await delete('/projects/$id');
      if (kDebugMode) {
        debugPrint('=== DELETE PROJECT RESPONSE ===');
        debugPrint('Status Code: ${response.statusCode}');
      }
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DELETE /projects/$id Error: $e');
      }
      return false;
    }
  }
  static Future<Map<String, dynamic>?> fetchTransactionById(String id) async {
    try {
      final response = await get('/transactions/$id');
      if (kDebugMode) {
        debugPrint('=== FETCH TRANSACTION BY ID ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['transaction'] ?? decoded['data'] ?? decoded;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('fetchTransactionById error: $e');
      }
      return null;
    }
  }
  static Future<List<dynamic>> fetchInventory(String projectId) async {
    try {
      String endpoint = '/transactions?limit=10000&filterByViewAccess=true';
      if (projectId.isNotEmpty) endpoint += '&project=$projectId';
      final response = await get(endpoint);
      if (kDebugMode) {
        debugPrint('fetchInventory status: ${response.statusCode}');
        debugPrint('fetchInventory body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          raw =
              (decoded['transactions'] ??
                      decoded['inventory'] ??
                      decoded['data'] ??
                      decoded['items'] ??
                      [])
                  as List<dynamic>;
        }
        final Map<String, Map<String, dynamic>> grouped = {};
        for (final t in raw) {
          final String rawType = (t['type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (rawType == 'income' || rawType == 'revenue') {
            continue;
          }
          final String approvalStatus = (t['approvalStatus'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          if (approvalStatus != 'approved') {
            continue;
          }
          final String itemName =
              (t['title'] ?? t['materialName'] ?? t['name'] ?? 'Unknown')
                  .toString()
                  .trim();
          String tabType = 'material';
          if (rawType == 'wages' || rawType == 'labour') {
            tabType = 'labour';
          } else if (rawType == 'expense' || rawType == 'equipment') {
            tabType = 'equipment';
          } else if (rawType == 'materials') {
            tabType = 'material';
          } else {
            final String originalCategory =
                (t['category'] ?? t['materialName'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (originalCategory == 'labour' ||
                originalCategory == 'wages' ||
                originalCategory == 'labor' ||
                originalCategory.contains('labour')) {
              tabType = 'labour';
            } else if (originalCategory == 'equipment' ||
                originalCategory == 'machinery' ||
                originalCategory == 'expense') {
              tabType = 'equipment';
            }
          }
          String unit = (t['unit'] ?? '').toString().trim();
          if (unit.toLowerCase() == 'units' || unit.toLowerCase() == 'unit') {
            unit = '';
          }
          final String key = '$itemName||$tabType||$unit';
          final double qty = (t['quantity'] ?? t['purchased'] ?? 0).toDouble();
          final bool isPositive =
              t['subType']?.toString().toLowerCase() != 'consumption' &&
              t['materialType']?.toString().toLowerCase() != 'usage';
          if (grouped.containsKey(key)) {
            if (isPositive) {
              grouped[key]!['purchased'] =
                  (grouped[key]!['purchased'] as double) + qty;
              grouped[key]!['closingStock'] =
                  (grouped[key]!['closingStock'] as double) + qty;
            } else {
              grouped[key]!['used'] = (grouped[key]!['used'] as double) + qty;
              grouped[key]!['closingStock'] =
                  (grouped[key]!['closingStock'] as double) - qty;
            }
            (grouped[key]!['transactions'] as List<dynamic>).add(t);
          } else {
            grouped[key] = {
              '_id': t['_id'] ?? key,
              'materialName': itemName,
              'category': tabType,
              'purchased': isPositive ? qty : 0.0,
              'used': isPositive ? 0.0 : qty,
              'closingStock': isPositive ? qty : -qty,
              'threshold': 10.0,
              'unit': unit,
              'transactions': [t],
            };
          }
        }
        for (final item in grouped.values) {
          final txs = item['transactions'] as List<dynamic>;
          txs.sort((a, b) {
            final dateA = a['date'] ?? '';
            final dateB = b['date'] ?? '';
            return dateB.toString().compareTo(dateA.toString());
          });
        }
        if (kDebugMode) {
          debugPrint('fetchInventory grouped items: ${grouped.length}');
        }
        return grouped.values.toList();
      } else {
        if (kDebugMode) {
          debugPrint(
            'fetchInventory failed: ${response.statusCode} ${response.body}',
          );
        }
        return [];
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Inventory GET Error: $e');
        debugPrint(stack.toString());
      }
      return [];
    }
  }
  static Future<void> addInventoryItem({
    required String materialName,
    required double purchased,
    required String unit,
    required String projectId,
    required String category,
    double threshold = 10,
  }) async {
    try {
      final response = await post('/inventory/add', {
        'materialName': materialName,
        'purchased': purchased,
        'unit': unit,
        'project': projectId,
        'category': category,
        'threshold': threshold,
      });
      if (response.statusCode != 200 && response.statusCode != 201) {
        if (kDebugMode) {
          debugPrint(
            'addInventoryItem failed (${response.statusCode}): ${response.body}',
          );
        }
        throw Exception('Failed to add inventory item');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('addInventoryItem Error: $e');
      }
      rethrow;
    }
  }
  static Future<List<dynamic>> searchMaterials({
    String? query,
    String? category,
    String? projectId,
  }) async {
    try {
      String endpoint = '/transactions?limit=10000&filterByViewAccess=true&';
      if (projectId != null && projectId.isNotEmpty) {
        endpoint += 'project=$projectId&';
      }
      if (query != null && query.isNotEmpty) endpoint += 'search=$query&';
      if (category != null && category.isNotEmpty && category != 'All') {
        String backendType = 'Materials';
        if (category.toLowerCase() == 'labour') backendType = 'Wages';
        if (category.toLowerCase() == 'equipment') backendType = 'Expense';
        endpoint += 'type=$backendType&';
      }
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          raw =
              (decoded['transactions'] ?? decoded['data'] ?? [])
                  as List<dynamic>;
        }
        final Map<String, Map<String, dynamic>> grouped = {};
        for (final t in raw) {
          final String rawType = (t['type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (rawType == 'income' || rawType == 'revenue') {
            continue;
          }
          final String approvalStatus = (t['approvalStatus'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          if (approvalStatus != 'approved') {
            continue;
          }
          final String itemName =
              (t['title'] ?? t['materialName'] ?? t['name'] ?? 'Unknown')
                  .toString()
                  .trim();
          String tabType = 'material';
          if (rawType == 'wages' || rawType == 'labour') {
            tabType = 'labour';
          } else if (rawType == 'expense' || rawType == 'equipment') {
            tabType = 'equipment';
          } else if (rawType == 'materials') {
            tabType = 'material';
          } else {
            final String originalCategory =
                (t['category'] ?? t['materialName'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (originalCategory == 'labour' ||
                originalCategory == 'wages' ||
                originalCategory == 'labor' ||
                originalCategory.contains('labour')) {
              tabType = 'labour';
            } else if (originalCategory == 'equipment' ||
                originalCategory == 'machinery' ||
                originalCategory == 'expense') {
              tabType = 'equipment';
            }
          }
          String unit = (t['unit'] ?? '').toString().trim();
          if (unit.toLowerCase() == 'units' || unit.toLowerCase() == 'unit') {
            unit = '';
          }
          final String key = '$itemName||$tabType||$unit';
          final double qty = (t['quantity'] ?? t['purchased'] ?? 0).toDouble();
          final bool isPositive =
              t['subType']?.toString().toLowerCase() != 'consumption' &&
              t['materialType']?.toString().toLowerCase() != 'usage';
          if (grouped.containsKey(key)) {
            if (isPositive) {
              grouped[key]!['purchased'] =
                  (grouped[key]!['purchased'] as double) + qty;
              grouped[key]!['closingStock'] =
                  (grouped[key]!['closingStock'] as double) + qty;
            } else {
              grouped[key]!['used'] = (grouped[key]!['used'] as double) + qty;
              grouped[key]!['closingStock'] =
                  (grouped[key]!['closingStock'] as double) - qty;
            }
            (grouped[key]!['transactions'] as List<dynamic>).add(t);
          } else {
            grouped[key] = {
              '_id': t['_id'] ?? key,
              'materialName': itemName,
              'category': tabType,
              'purchased': isPositive ? qty : 0.0,
              'used': isPositive ? 0.0 : qty,
              'closingStock': isPositive ? qty : -qty,
              'threshold': 10.0,
              'unit': unit,
              'transactions': [t],
            };
          }
        }
        for (final item in grouped.values) {
          final txs = item['transactions'] as List<dynamic>;
          txs.sort((a, b) {
            final dateA = a['date'] ?? '';
            final dateB = b['date'] ?? '';
            return dateB.toString().compareTo(dateA.toString());
          });
        }
        return grouped.values.toList();
      } else {
        throw Exception('Search failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Search API Error: $e');
      }
      return [];
    }
  }
  static Future<List<dynamic>> fetchDailyTasks() async {
    try {
      final response = await get('/tasks/daily');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map) return decoded['tasks'] ?? decoded['data'] ?? [];
        return [];
      } else {
        throw Exception('Failed to load daily tasks');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Tasks API Error: $e');
      }
      return [];
    }
  }
  static Future<String?> resetPassword(String email) async {
    try {
      final response = await post('/auth/forgot-password', {'email': email});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = json.decode(response.body);
        return body['resetToken'] as String?;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('resetPassword Error: $e');
      rethrow;
    }
  }
  static Future<void> confirmResetPassword({
    required String token,
    required String password,
  }) async {
    try {
      final response = await post('/auth/reset-password', {
        'token': token,
        'password': password,
      });
      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = json.decode(response.body);
        throw Exception(body['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('confirmResetPassword Error: $e');
      rethrow;
    }
  }
  static Future<List<dynamic>> fetchRecentTransactions({
    required String projectId,
    required String type,
    String? userId,
  }) async {
    try {
      String url = '/transactions?project=$projectId&type=$type&limit=5';
      if (userId != null && userId.isNotEmpty) {
        url += '&createdBy=$userId';
      }
      final response = await get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map) {
          final list = (decoded['transactions'] ?? decoded['data'] ?? []) as List<dynamic>;
          return list.where((tx) => tx['type'] == type).toList();
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('fetchRecentTransactions Error: $e');
      }
      return [];
    }
  }
  static Future<List<Map<String, dynamic>>> fetchSuggestions({
    required String projectId,
    required String type,
    String? userId,
  }) async {
    try {
      List<dynamic> projectTxs = [];
      try {
        String projectUrl =
            '/transactions?limit=10000&project=$projectId&type=$type';
        if (userId != null && userId.isNotEmpty) {
          projectUrl += '&createdBy=$userId';
        }
        final r = await get(projectUrl);
        if (r.statusCode == 200) {
          final d = json.decode(r.body);
          if (d is List) {
            projectTxs = d;
          } else if (d is Map) {
            final list = (d['transactions'] ?? d['data'] ?? []) as List<dynamic>;
            projectTxs = list.where((tx) => tx['type'] == type).toList();
          }
        }
      } catch (_) {}
      List<dynamic> globalTxs = [];
      try {
        String globalUrl = '/transactions?limit=10000&type=$type';
        if (userId != null && userId.isNotEmpty) {
          globalUrl += '&createdBy=$userId';
        }
        final r = await get(globalUrl);
        if (r.statusCode == 200) {
          final d = json.decode(r.body);
          if (d is List) {
            globalTxs = d;
          } else if (d is Map) {
            globalTxs = (d['transactions'] ?? d['data'] ?? []) as List<dynamic>;
          }
        }
      } catch (_) {}
      final Map<String, Map<String, dynamic>> byTitle = {};
      final Map<String, int> frequency = {};
      final Map<String, bool> isCurrentProject = {};
      for (final rawTx in projectTxs) {
        final tx = rawTx as Map<String, dynamic>;
        final title = (tx['title'] ?? tx['name'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final key = title.toLowerCase();
        frequency[key] = (frequency[key] ?? 0) + 1;
        isCurrentProject[key] = true;
        if (!byTitle.containsKey(key)) {
          byTitle[key] = Map<String, dynamic>.from(tx);
        } else {
          final existingDate = byTitle[key]!['date']?.toString() ?? '';
          final newDate = tx['date']?.toString() ?? '';
          if (newDate.compareTo(existingDate) > 0) {
            byTitle[key] = Map<String, dynamic>.from(tx);
          }
        }
      }
      for (final rawTx in globalTxs) {
        final tx = rawTx as Map<String, dynamic>;
        final title = (tx['title'] ?? tx['name'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final key = title.toLowerCase();
        if (!byTitle.containsKey(key)) {
          byTitle[key] = Map<String, dynamic>.from(tx);
          frequency[key] = 1;
          isCurrentProject[key] = false;
        } else if (isCurrentProject[key] != true) {
          final existingDate = byTitle[key]!['date']?.toString() ?? '';
          final newDate = tx['date']?.toString() ?? '';
          if (newDate.compareTo(existingDate) > 0) {
            byTitle[key] = Map<String, dynamic>.from(tx);
          }
          frequency[key] = (frequency[key] ?? 0) + 1;
        }
      }
      final entries = byTitle.entries.toList()
        ..sort((a, b) {
          final aKey = a.key;
          final bKey = b.key;
          final aProj = isCurrentProject[aKey] == true ? 1 : 0;
          final bProj = isCurrentProject[bKey] == true ? 1 : 0;
          if (aProj != bProj) return bProj - aProj;
          final aDate = a.value['date']?.toString() ?? '';
          final bDate = b.value['date']?.toString() ?? '';
          final dateCmp = bDate.compareTo(aDate);
          if (dateCmp != 0) return dateCmp;
          final aFreq = frequency[aKey] ?? 0;
          final bFreq = frequency[bKey] ?? 0;
          return bFreq - aFreq;
        });
      final result = <Map<String, dynamic>>[];
      for (final e in entries.take(50)) {
        final record = Map<String, dynamic>.from(e.value)
          ..['\$freq'] = frequency[e.key] ?? 1
          ..['\$isCurrentProject'] = isCurrentProject[e.key] ?? false;
        result.add(record);
      }
      if (kDebugMode) {
        debugPrint(
          'fetchSuggestions [$type]: ${result.length} unique suggestions',
        );
      }
      return result;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('fetchSuggestions Error: $e');
        debugPrint(stack.toString());
      }
      return [];
    }
  }
  static Future<Map<String, dynamic>?> fetchPendingApprovals() async {
    try {
      final response = await get('/approvals/pending');
      if (kDebugMode) {
        debugPrint('fetchPendingApprovals status: ${response.statusCode}');
        debugPrint('fetchPendingApprovals body: ${response.body}');
      }
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchPendingApprovals error: $e');
      return null;
    }
  }
  static Future<bool> assignSupervisorOversight(
    String supervisorId,
    List<String> roles,
  ) async {
    try {
      final response = await put('/users/$supervisorId/oversight', {
        'overseesRoles': roles,
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('assignSupervisorOversight error: $e');
      return false;
    }
  }
  static Future<Map<String, dynamic>?> fetchApprovalsHistory({
    String? projectId,
  }) async {
    try {
      String endpoint = '/approvals/history';
      if (projectId != null && projectId.isNotEmpty) {
        endpoint += '?project=$projectId';
      }
      final response = await get(endpoint);
      if (kDebugMode) {
        debugPrint('fetchApprovalsHistory status: ${response.statusCode}');
        debugPrint('fetchApprovalsHistory body: ${response.body}');
      }
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchApprovalsHistory error: $e');
      return null;
    }
  }
  static Future<bool> approveTransaction(String txId) async {
    try {
      final response = await put('/transactions/$txId/approve', {});
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('approveTransaction error: $e');
      return false;
    }
  }
  static Future<bool> rejectTransaction(String txId, String reason) async {
    try {
      final response = await put('/transactions/$txId/reject', {
        'rejectionReason': reason,
      });
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('rejectTransaction error: $e');
      return false;
    }
  }
  static Future<bool> approveProjectUpdate(String updateId) async {
    try {
      final response = await put('/project-updates/$updateId/approve', {});
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('approveProjectUpdate error: $e');
      return false;
    }
  }
  static Future<bool> rejectProjectUpdate(
    String updateId,
    String reason,
  ) async {
    try {
      final response = await put('/project-updates/$updateId/reject', {
        'rejectionReason': reason,
      });
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('rejectProjectUpdate error: $e');
      return false;
    }
  }
  static Future<List<dynamic>> fetchMyRecentEntries({String? projectId}) async {
    try {
      String url = '/transactions?limit=10&filterByViewAccess=true';
      if (projectId != null && projectId.isNotEmpty) {
        url += '&project=$projectId';
      }
      final response = await get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> rawEntries = decoded is List
            ? decoded
            : (decoded['transactions'] ?? decoded['data'] ?? [])
                  as List<dynamic>;
        final filtered = rawEntries.where((entry) {
          if (entry is! Map<String, dynamic>) return false;
          final type = (entry['type'] ?? '').toString().toLowerCase().trim();
          final approvalStatus = (entry['approvalStatus'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          if (type == 'income' || type == 'revenue') return false;
          if (approvalStatus == 'rejected') return false;
          if (approvalStatus != 'approved') {
            return false;
          }
          return true;
        }).toList();
        filtered.sort((a, b) {
          final aDate = (a['date'] ?? a['createdAt'] ?? '').toString();
          final bDate = (b['date'] ?? b['createdAt'] ?? '').toString();
          return bDate.compareTo(aDate);
        });
        return filtered.take(10).toList();
      }
    } catch (e) {
      debugPrint('fetchMyRecentEntries error: $e');
    }
    return [];
  }
  static Future<Map<String, dynamic>?> requestEsignature(
      String clientEmail, Map<String, dynamic> meta) async {
    try {
      final response = await post(
        '/esign/request',
        {'clientEmail': clientEmail, 'meta': meta},
      );
      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('requestEsignature error: $e');
    }
    return null;
  }
  static Future<Map<String, dynamic>?> checkEsignatureStatus(String requestId) async {
    try {
      final response = await get('/esign/status/$requestId');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('checkEsignatureStatus error: $e');
    }
    return null;
  }
  static Future<Map<String, dynamic>?> getEsignatureDetails(String token) async {
    try {
      final response = await get('/esign/details/$token');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getEsignatureDetails error: $e');
    }
    return null;
  }
  static Future<Map<String, dynamic>> fetchNotificationPage({int page = 1, int limit = 50}) async {
    try {
      final response = await get('/notifications?page=$page&limit=$limit');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchNotificationPage error: $e');
    }
    return {'items': <dynamic>[], 'total': 0, 'unreadCount': 0, 'page': 1, 'pages': 1};
  }

  static Future<List<dynamic>> getNotifications() async {
    final data = await fetchNotificationPage();
    return (data['items'] as List?) ?? [];
  }

  static Future<int> getUnreadNotificationCount() async {
    try {
      final response = await get('/notifications/unread-count');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) return (data['unreadCount'] as int?) ?? 0;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getUnreadNotificationCount error: $e');
    }
    return 0;
  }

  static Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final response = await get('/notifications/preferences');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return Map<String, dynamic>.from((data['preferences'] as Map?) ?? {});
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getNotificationPreferences error: $e');
    }
    return {};
  }

  static Future<bool> saveNotificationPreferences(Map<String, dynamic> preferences) async {
    try {
      final response = await put('/notifications/preferences', {'preferences': preferences});
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('saveNotificationPreferences error: $e');
      return false;
    }
  }

  static Future<bool> markNotificationAsRead(String id) async {
    try {
      final response = await put('/notifications/$id/read', {});
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('markNotificationAsRead error: $e');
      return false;
    }
  }

  static Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await put('/notifications/read-all', {});
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('markAllNotificationsAsRead error: $e');
      return false;
    }
  }

  static Future<bool> clearAllNotifications() async {
    try {
      final response = await delete('/notifications/all');
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('clearAllNotifications error: $e');
      return false;
    }
  }
}
