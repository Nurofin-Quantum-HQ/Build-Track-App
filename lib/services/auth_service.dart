import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:buildtrack_mobile/config/navigator_key.dart';

class AuthService {
  // [BT-SEC-05] The JWT lives in OS-backed secure storage (Keystore/Keychain),
  // not SharedPreferences (which is plaintext on Android). All token reads go
  // through getToken() so there is a single source of truth.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kTokenKey = 'token';
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    try {
      final response = await ApiService.post('/auth/login', {
        'email': email,
        'password': password,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = data['token'];
        final Map<String, dynamic> user = Map<String, dynamic>.from(
          data['user'] ?? {},
        );
        if (token == null) {
          throw Exception('Token not found in login response');
        }
        await _secure.write(key: _kTokenKey, value: token); // [BT-SEC-05]
        final prefs = await SharedPreferences.getInstance();
        final roleStr = user['role']?.toString() ?? 'Mason';
        await prefs.setString('user_role', roleStr);
        await prefs.setString('cached_email', email); // Cache the email for auto-fill
        await UserSession.fromLoginResponse(user);
        debugPrint(
          '[AuthService] Login OK — role=$roleStr '
          'projectId=${UserSession.projectId} '
          'permissions=${UserSession.permissions}',
        );
        return data;
      } else {
        final message = data is Map && data.containsKey('message')
            ? data['message'].toString()
            : 'Login failed (${response.statusCode})';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('[AuthService] Login error: $e');
      rethrow;
    }
  }
  static Future<void> logout({bool sessionExpired = false}) async {
    await _secure.delete(key: _kTokenKey); // [BT-SEC-05]
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');       // clear any pre-migration plaintext token
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await UserSession.clear();
    debugPrint('[AuthService] Logged out — session cleared');

    if (globalNavigatorKey.currentContext != null) {
      if (sessionExpired) {
        ScaffoldMessenger.of(globalNavigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: const Text('Session expired. Please log in again.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
      Navigator.of(globalNavigatorKey.currentContext!).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  static Future<bool> validateSession() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return false;

      // We call the API directly here to avoid interceptor loops if needed, 
      // but using ApiService.get is fine since the interceptor will just call logout() on 401 anyway.
      // Wait, let's use the underlying http package to avoid circular dependency if ApiService calls AuthService.logout().
      // Actually, we can just use ApiService.get, but let's make sure ApiService is ready.
      // Alternatively, just make an http request directly.
      final response = await ApiService.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['user'] != null) {
          final Map<String, dynamic> user = Map<String, dynamic>.from(data['user']);
          await UserSession.fromLoginResponse(user);
          return true;
        }
      }
      // If 401, the interceptor will trigger logout. So we just return false here.
      return false;
    } catch (e) {
      debugPrint('[AuthService] Session validation error: $e');
      // On network error, we don't necessarily want to log out. We might be offline.
      // We assume valid if we have a token but are offline, until the first 401 happens.
      // Returning true here allows the app to proceed if it's an offline scenario.
      return true; 
    }
  }

  static Future<String?> getToken() async {
    // [BT-SEC-05] Prefer secure storage. One-time migration: if a token from a
    // previous app version is still in SharedPreferences, move it into secure
    // storage and clear the plaintext copy, so existing sessions survive the update.
    final secureToken = await _secure.read(key: _kTokenKey);
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString('token') ?? prefs.getString('jwt_token');
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: _kTokenKey, value: legacy);
      await prefs.remove('token');
      await prefs.remove('jwt_token');
      return legacy;
    }
    return null;
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
