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
      print('Push notifications are not supported on Web. Skipping init.');
      return;
    }

    if (!_listenersConfigured) {
      const androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings = InitializationSettings(
        android: androidInitSettings,
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
      print('Notification permission was not granted.');
      return;
    }

    final token = await _firebaseMessaging.getToken();

    if (token != null && token.isNotEmpty) {
      await _registerTokenWithBackend(token);
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
        print('FCM token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      print('FCM token registration error: $e');
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
