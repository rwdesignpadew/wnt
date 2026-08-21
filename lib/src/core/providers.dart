import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'storage/session_store.dart';
import 'notifications/push_notification_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService(ref.watch(apiClientProvider)));
