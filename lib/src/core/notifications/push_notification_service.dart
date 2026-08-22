import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';

class PushNotificationService {
  PushNotificationService(this._api);

  final ApiClient _api;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    FirebaseMessaging.onMessage.listen((message) async {
      if (Platform.isIOS) return;
      final notification = message.notification;
      if (notification == null) return;
      await _notifications.show(
        id: notification.hashCode,
        title: notification.title ?? 'Woda na telefon',
        body: notification.body ?? '',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'orders',
            'Zamówienia',
            channelDescription: 'Powiadomienia o nowych zamówieniach',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<void> register(String apiToken) async {
    await _initialize();
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await messaging.getToken();
    if (token != null) await _save(apiToken, token);
    messaging.onTokenRefresh.listen((token) => _save(apiToken, token));
  }

  Future<void> unregister(String apiToken) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await _api.send(
        'DELETE',
        '/mobile/device-token',
        token: apiToken,
        body: {'token': token},
      );
    } catch (_) {}
  }

  Future<void> _save(String apiToken, String token) => _api.post(
    '/mobile/device-token',
    token: apiToken,
    body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
  );
}
