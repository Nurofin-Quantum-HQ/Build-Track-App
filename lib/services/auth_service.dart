import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:buildtrack_mobile/config/navigator_key.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:buildtrack_mobile/controller/theme_provider.dart';
import 'package:buildtrack_mobile/screen/reports/report.dart' show ReportFilterState;
import 'package:buildtrack_mobile/services/push_notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class AuthService {
  // [BT-SEC-05] The JWT lives in OS-backed secure storage (Keystore/Keychain),
  // not SharedPreferences (which is plaintext on Android). All token reads go
  // through getToken() so there is a single source of truth.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kTokenKey = 'token';

  /// True from the moment a logout starts until the next successful login.
  /// Responses that come back 401 after that (requests that were in flight
  /// when the user tapped Logout, or screens refreshing while they unmount)
  /// are not a "session expired" event — the session was ended on purpose —
  /// so [handleUnauthorized] ignores them. It also makes a real expiry show
  /// its alert once, not once per concurrent 401.
  static bool _sessionEnded = false;
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
        _sessionEnded = false;
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
  /// Called by ApiService for every 401. Logs out with the "Session expired"
  /// alert only when a signed-in session was actually rejected by the server:
  /// - not after an intentional logout (in-flight requests coming back 401),
  /// - not when no token is stored (e.g. a wrong password on the login screen),
  /// - and only once when several requests fail together.
  static Future<void> handleUnauthorized() async {
    if (_sessionEnded) return;
    final token = await getToken();
    if (token == null || token.isEmpty) return;
    if (_sessionEnded) return; // a logout started while we were reading the token
    await logout(sessionExpired: true);
  }

  static Future<void> logout({bool sessionExpired = false}) async {
    // Set synchronously, before any await, so 401s that race with this logout
    // are recognised as part of it.
    _sessionEnded = true;
    // Stop pushes for this account on this device (needs the JWT, so before
    // it is deleted). Time-boxed; never throws.
    await PushNotificationService.unregister();
    await _secure.delete(key: _kTokenKey); // [BT-SEC-05]
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');       // clear any pre-migration plaintext token
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await UserSession.clear();
    ReportFilterState.reset();
    debugPrint('[AuthService] Logged out — session cleared');

    final ctx = globalNavigatorKey.currentContext;
    if (ctx != null) {
      // Every logout path (button, session expiry, delete account) clears the
      // previous account's in-memory data and theme.
      try {
        ctx.read<ProjectProvider>().clear();
        ctx.read<InventoryProvider>().clear();
        ctx.read<SubscriptionProvider>().clear();
        ctx.read<ThemeProvider>().reload();
      } catch (e) {
        debugPrint('[AuthService] provider reset after logout failed: $e');
      }
    }

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

  /// Startup check of the stored token against GET /auth/me.
  ///
  /// * true  — the server accepted it (session refreshed), **or** the server
  ///   couldn't be asked (offline, timeout, 5xx): keep the user signed in.
  /// * false — no token, or the server rejected it (401/403/404 …): the
  ///   caller sends the user to Login.
  ///
  /// Uses a plain request (not ApiService.get) so a 401 here doesn't fire the
  /// global "session expired" logout before the app is even drawn — and so
  /// a 401 is never mistaken for "offline" (that left expired sessions stuck
  /// on an empty Home).
  static Future<bool> validateSession({Duration timeout = const Duration(seconds: 8)}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    http.Response response;
    try {
      response = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/me'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(timeout);
    } catch (e) {
      debugPrint('[AuthService] Session check failed (offline?): $e');
      return true;
    }
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['user'] is Map) {
          await UserSession.fromLoginResponse(Map<String, dynamic>.from(data['user'] as Map));
          _sessionEnded = false;
          return true;
        }
      } catch (e) {
        debugPrint('[AuthService] /auth/me parse error: $e');
      }
      return true; // reachable + accepted, odd body: keep the cached session
    }
    if (response.statusCode >= 500) return true; // server trouble ≠ signed out
    debugPrint('[AuthService] Session rejected (${response.statusCode})');
    return false;
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
