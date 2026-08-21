import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/client_repository.dart';

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(ref.watch(apiClientProvider)),
);

final clientHomeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  final token = ref.watch(authControllerProvider).session!.token;
  return ref.watch(clientRepositoryProvider).home(token);
});

final clientDocumentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final token = ref.watch(authControllerProvider).session!.token;
      return ref.watch(clientRepositoryProvider).documents(token);
    });

final clientTrackingProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) {
    final token = ref.watch(authControllerProvider).session!.token;
    return ref.watch(clientRepositoryProvider).tracking(token);
  },
);
