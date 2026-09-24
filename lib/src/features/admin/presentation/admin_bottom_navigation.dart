import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/application/home_navigation_provider.dart';
import '../application/admin_providers.dart';

Widget adminBottomNavigation(
  BuildContext context,
  WidgetRef ref, {
  int selectedIndex = 4,
}) {
  final summary = ref.watch(adminSummaryProvider).valueOrNull;
  final newOrders = _alertCount(summary, 'orders');
  final openServices =
      ref
          .watch(authControllerProvider)
          .session!
          .user
          .hasAdminPermission('service')
      ? _alertCount(summary, 'service')
      : 0;
  final destinations = [
    const NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Start',
    ),
    const NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Trasy',
    ),
    NavigationDestination(
      icon: _badgedIcon(Icons.shopping_cart_outlined, newOrders),
      selectedIcon: _badgedIcon(Icons.shopping_cart, newOrders),
      label: 'Zamówienia',
    ),
    const NavigationDestination(
      icon: Icon(Icons.description_outlined),
      selectedIcon: Icon(Icons.description),
      label: 'Dokumenty',
    ),
    NavigationDestination(
      icon: _badgedIcon(Icons.more_horiz, openServices),
      selectedIcon: _badgedIcon(Icons.more_horiz, openServices),
      label: 'Więcej',
    ),
  ];

  final safeIndex = selectedIndex < 0
      ? 0
      : selectedIndex >= destinations.length
      ? destinations.length - 1
      : selectedIndex;

  return MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1,
    child: NavigationBar(
      selectedIndex: safeIndex,
      destinations: destinations,
      onDestinationSelected: (index) {
        ref.read(homeNavigationIndexProvider.notifier).state = index;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    ),
  );
}

Widget _badgedIcon(IconData icon, int count) {
  final child = Icon(icon);
  if (count < 1) return child;
  return Badge(
    backgroundColor: WntColors.error,
    label: Text(count > 99 ? '99+' : '$count'),
    child: child,
  );
}

int _alertCount(Map<String, dynamic>? summary, String kind) {
  final alerts = summary?['alerts'];
  if (alerts is! List) return 0;
  for (final raw in alerts.whereType<Map>()) {
    if (raw['kind']?.toString() == kind) {
      return int.tryParse('${raw['value']}') ?? 0;
    }
  }
  return 0;
}
