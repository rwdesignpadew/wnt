import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/application/home_navigation_provider.dart';

Widget adminBottomNavigation(BuildContext context, WidgetRef ref) {
  const destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Start',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Trasy',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart),
      label: 'Zamówienia',
    ),
    NavigationDestination(
      icon: Icon(Icons.description_outlined),
      selectedIcon: Icon(Icons.description),
      label: 'Dokumenty',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz),
      selectedIcon: Icon(Icons.more_horiz),
      label: 'Więcej',
    ),
  ];

  return MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1,
    child: NavigationBar(
      selectedIndex: 4,
      destinations: destinations,
      onDestinationSelected: (index) {
        ref.read(homeNavigationIndexProvider.notifier).state = index;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    ),
  );
}
