import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../admin/application/admin_providers.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../admin/presentation/admin_documents_screen.dart';
import '../../admin/presentation/admin_more_screen.dart';
import '../../admin/presentation/admin_routes_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_session.dart';
import '../../client/presentation/client_account_screen.dart';
import '../../client/presentation/client_documents_screen.dart';
import '../../client/presentation/client_order_screen.dart';
import '../../client/presentation/client_tracking_screen.dart';
import '../../driver/presentation/driver_documents_screen.dart';
import '../../driver/presentation/driver_load_screen.dart';
import '../../driver/presentation/driver_route_screen.dart';
import '../application/home_navigation_provider.dart';

class RoleHomeScreen extends ConsumerStatefulWidget {
  const RoleHomeScreen({super.key});

  @override
  ConsumerState<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends ConsumerState<RoleHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final role = ref.read(authControllerProvider).session?.user.role;
      if (role == UserRole.driver) {
        WakelockPlus.enable();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session!;
    final destinations = _destinations(session.user.role);
    final isTablet = MediaQuery.sizeOf(context).width >= 800;
    final newOrders = session.user.role == UserRole.admin
        ? _newOrdersCount(ref.watch(adminSummaryProvider).valueOrNull)
        : 0;
    var index = ref.watch(homeNavigationIndexProvider);
    if (index >= destinations.length) {
      index = 0;
      Future.microtask(
        () => ref.read(homeNavigationIndexProvider.notifier).state = 0,
      );
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/wnt_app.png', width: 36, height: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Woda na telefon'),
                  Text(
                    session.user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wyloguj się',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isTablet
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (value) =>
                      ref.read(homeNavigationIndexProvider.notifier).state =
                          value,
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: _navigationIcon(item.icon, item.label, newOrders),
                        selectedIcon: _navigationIcon(
                          item.selectedIcon,
                          item.label,
                          newOrders,
                        ),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: _page(session.user.role, index),
                    ),
                  ),
                ),
              ],
            )
          : _page(session.user.role, index),
      bottomNavigationBar: isTablet
          ? null
          : MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1,
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (value) =>
                    ref.read(homeNavigationIndexProvider.notifier).state =
                        value,
                destinations: [
                  for (final item in destinations)
                    NavigationDestination(
                      icon: _navigationIcon(item.icon, item.label, newOrders),
                      selectedIcon: _navigationIcon(
                        item.selectedIcon,
                        item.label,
                        newOrders,
                      ),
                      label: item.label,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _page(UserRole role, int index) {
    if (role == UserRole.admin) {
      return switch (index) {
        0 => const AdminDashboardScreen(),
        1 => const AdminRoutesScreen(),
        2 => const AdminOperationsScreen(
          dataKey: 'orders',
          title: 'Zamówienia',
          embedded: true,
        ),
        3 => const AdminDocumentsScreen(),
        _ => const AdminMoreScreen(),
      };
    }
    if (role == UserRole.client) {
      return switch (index) {
        0 => const ClientOrderScreen(),
        1 => const ClientTrackingScreen(),
        2 => const ClientDocumentsScreen(),
        _ => const ClientAccountScreen(),
      };
    }
    if (role == UserRole.driver) {
      return switch (index) {
        0 => const DriverRouteScreen(),
        1 => const DriverLoadScreen(),
        2 => const DriverDocumentsScreen(),
        _ => const _DriverAccountScreen(),
      };
    }
    return const SizedBox.shrink();
  }
}

class _DriverAccountScreen extends ConsumerWidget {
  const _DriverAccountScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).session!.user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Konto kierowcy',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.name),
            subtitle: Text(user.email),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout_outlined),
          label: const Text('Wyloguj się'),
        ),
      ],
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

List<_Destination> _destinations(UserRole role) => switch (role) {
  UserRole.admin => const [
    _Destination('Start', Icons.dashboard_outlined, Icons.dashboard),
    _Destination('Trasy', Icons.route_outlined, Icons.route),
    _Destination(
      'Zamówienia',
      Icons.shopping_cart_outlined,
      Icons.shopping_cart,
    ),
    _Destination('Dokumenty', Icons.description_outlined, Icons.description),
    _Destination('Więcej', Icons.more_horiz, Icons.more_horiz),
  ],
  UserRole.driver => const [
    _Destination('Trasa', Icons.route_outlined, Icons.route),
    _Destination('Załadunek', Icons.inventory_2_outlined, Icons.inventory_2),
    _Destination('Dokumenty', Icons.description_outlined, Icons.description),
    _Destination('Konto', Icons.person_outline, Icons.person),
  ],
  UserRole.client => const [
    _Destination('Zamów', Icons.water_drop_outlined, Icons.water_drop),
    _Destination(
      'Dostawa',
      Icons.local_shipping_outlined,
      Icons.local_shipping,
    ),
    _Destination('Dokumenty', Icons.description_outlined, Icons.description),
    _Destination('Konto', Icons.person_outline, Icons.person),
  ],
};

Widget _navigationIcon(IconData icon, String label, int newOrders) {
  final child = Icon(icon);
  if (label != 'Zamówienia' || newOrders < 1) return child;
  return Badge(
    label: Text(newOrders > 99 ? '99+' : '$newOrders'),
    child: child,
  );
}

int _newOrdersCount(Map<String, dynamic>? summary) {
  final alerts = summary?['alerts'];
  if (alerts is! List) return 0;
  for (final raw in alerts.whereType<Map>()) {
    if (raw['kind']?.toString() == 'orders') {
      return int.tryParse('${raw['value']}') ?? 0;
    }
  }
  return 0;
}
