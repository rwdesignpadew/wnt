import 'dart:async';
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
  bool _tokenRefreshListening = false;
  String? _apiToken;
  Timer? _registrationRetry;

  void _scheduleRetry(String apiToken) {
    _registrationRetry?.cancel();
    _registrationRetry = Timer(
      const Duration(seconds: 30),
      () => register(apiToken),
    );
  }

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
    _apiToken = apiToken;
    await _initialize();
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    if (Platform.isIOS) {
      for (var attempt = 0; attempt < 15; attempt++) {
        if (await messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (await messaging.getAPNSToken() == null) {
        _scheduleRetry(apiToken);
        return;
      }
    }
    final token = await messaging.getToken();
    if (token == null) {
      _scheduleRetry(apiToken);
      return;
    }
    await _save(apiToken, token);
    _registrationRetry?.cancel();
    if (!_tokenRefreshListening) {
      _tokenRefreshListening = true;
      messaging.onTokenRefresh.listen((token) {
        final currentApiToken = _apiToken;
        if (currentApiToken != null) _save(currentApiToken, token);
      });
    }
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
