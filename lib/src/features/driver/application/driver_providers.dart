import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => DriverRepository(ref.watch(apiClientProvider)),
);

final selectedDriverRouteIdProvider = StateProvider<int?>((ref) => null);

final driverRouteProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final token = ref.watch(authControllerProvider).session!.token;
  final routeId = ref.watch(selectedDriverRouteIdProvider);
  return ref.watch(driverRepositoryProvider).route(token, routeId: routeId);
});
