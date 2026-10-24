import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart'; // Adjusting to the actual config
import '../services/auth_service.dart'; // [BT-SEC-05] token via secure storage

import 'package:flutter/foundation.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _listenersConfigured = false;

  static Future<void> init() async {
    // Firebase is initialized once in main.dart.
    // Do not call Firebase.initializeApp() here.
    if (kIsWeb) {
      debugPrint('Push notifications are not supported on Web. Skipping init.');
      return;
    }

    if (!_listenersConfigured) {
      const androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS needs its own settings — without them initialize() throws on
      // iOS ("iOS settings must be set…") and login failed every time.
      // Permission is asked by FirebaseMessaging below, not here.
      const darwinInitSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: darwinInitSettings,
      );

      await _localNotificationsPlugin.initialize(initSettings);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      _firebaseMessaging.onTokenRefresh.listen(_registerTokenWithBackend);

      _listenersConfigured = true;
    }

    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('Notification permission was not granted.');
      return;
    }

    final token = await _firebaseMessaging.getToken();

    if (token != null && token.isNotEmpty) {
      await _registerTokenWithBackend(token);
    }
  }

  /// Logout: stop this device receiving the signed-out user's pushes.
  /// Tells the backend to forget this device token (needs the JWT, so call it
  /// before the token is deleted), then deletes the FCM token itself — that
  /// alone makes any copy the server still holds stop delivering. Never
  /// throws and never takes more than a few seconds.
  static Future<void> unregister() async {
    if (kIsWeb) return;
    try {
      final jwtToken = await AuthService.getToken();
      String? fcmToken;
      try {
        fcmToken = await _firebaseMessaging.getToken().timeout(const Duration(seconds: 3));
      } catch (_) {}
      if (jwtToken != null && jwtToken.isNotEmpty && fcmToken != null && fcmToken.isNotEmpty) {
        try {
          await http
              .delete(
                Uri.parse('${ApiService.baseUrl}/notifications/device-token'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $jwtToken',
                },
                body: jsonEncode({'token': fcmToken}),
              )
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('FCM token unregister error: $e');
        }
      }
      await _firebaseMessaging.deleteToken().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('FCM deleteToken error: $e');
    }
  }

  static Future<void> _registerTokenWithBackend(String fcmToken) async {
    final jwtToken = await AuthService.getToken(); // [BT-SEC-05]

    if (jwtToken == null || jwtToken.isEmpty) {
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiService.baseUrl}/notifications/device-token',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('FCM token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  static Future<void> _showLocalNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;

    if (notification == null) return;

    await _localNotificationsPlugin.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'buildtrack_high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'Notifications for tasks, inventory, and payments.',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}
