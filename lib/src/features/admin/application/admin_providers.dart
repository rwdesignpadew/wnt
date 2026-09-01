import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);
String _token(Ref ref) => ref.watch(authControllerProvider).session!.token;
final adminSummaryProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(adminRepositoryProvider).summary(_token(ref)),
);
final adminOperationsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(adminRepositoryProvider).operations(_token(ref));
});
final adminNotificationsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final timer = Timer(const Duration(seconds: 20), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(adminRepositoryProvider).notifications(_token(ref));
});
final adminRoutesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).routes(_token(ref)),
);
final adminClientsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).clients(_token(ref)),
);
final adminDocumentsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).documents(_token(ref)),
);
final adminProductsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).products(_token(ref)),
);
