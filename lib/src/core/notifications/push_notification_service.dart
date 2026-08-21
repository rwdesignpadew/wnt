import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../network/api_client.dart';

class PushNotificationService {
  PushNotificationService(this._api);

  final ApiClient _api;

  Future<void> register(String apiToken) async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await messaging.getToken();
    if (token != null) await _save(apiToken, token);
    messaging.onTokenRefresh.listen((token) => _save(apiToken, token));
  }

  Future<void> unregister(String apiToken) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await _api.send('DELETE', '/mobile/device-token', token: apiToken, body: {'token': token});
    } catch (_) {}
  }

  Future<void> _save(String apiToken, String token) => _api.post(
    '/mobile/device-token',
    token: apiToken,
    body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
  );
}
