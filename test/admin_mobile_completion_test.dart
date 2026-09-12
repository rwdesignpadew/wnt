import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final backendRoot = Directory('../../sanitization-test-app-20260910');

  test('salda dzierżawy i uwagi zachowują dolne menu administratora', () {
    final source = File(
      'lib/src/features/admin/presentation/admin_management_screens.dart',
    ).readAsStringSync();

    expect(
      'bottomNavigationBar: adminBottomNavigation(context, ref)'.allMatches(
        source,
      ),
      hasLength(3),
    );
    expect(source, contains("('debt', 'Zaległości'"));
    expect(source, contains("('credit', 'Nadpłaty'"));
    expect(source, contains("('all', 'Wszyscy'"));
  });

  test('dzierżawy mają dodanie, zwrot i anulowanie oczekującej pozycji', () {
    final mobile = File(
      'lib/src/features/admin/presentation/admin_management_screens.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/admin/data/admin_repository.dart',
    ).readAsStringSync();
    final routes = File(
      '${backendRoot.path}/routes/api.php',
    ).readAsStringSync();
    final controller = File(
      '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(mobile, contains('Nowa dzierżawa'));
    expect(mobile, contains('Przyjmij i utwórz PZ'));
    expect(repository, contains('storeRental'));
    expect(repository, contains('deletePendingRental'));
    expect(routes, contains("Route::post('/admin/rentals'"));
    expect(routes, contains('/admin/rentals/pending/{document}'));
    expect(controller, contains('function storeRental'));
    expect(controller, contains('function destroyPendingRental'));
    expect(controller, contains('rental_request_data'));
  });

  test(
    'sanityzacja zaległa może zostać dodana do istniejącej lub nowej trasy',
    () {
      final mobile = File(
        'lib/src/features/admin/presentation/admin_more_screen.dart',
      ).readAsStringSync();
      final routes = File(
        '${backendRoot.path}/routes/api.php',
      ).readAsStringSync();
      final controller = File(
        '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
      ).readAsStringSync();

      expect(mobile, contains("value: 'plan_route'"));
      expect(mobile, contains('Dodaj zaległą do trasy'));
      expect(mobile, contains("value: 'existing'"));
      expect(mobile, contains("value: 'new'"));
      expect(routes, contains('/sanitizations/{sanitization}/plan-route'));
      expect(controller, contains('function planSanitizationRoute'));
      expect(controller, contains("\$sanitization->status !== 'overdue'"));
    },
  );

  test('trasy mają osobne zakładki i bezpieczne przenoszenie pominiętych', () {
    final mobile = File(
      'lib/src/features/admin/presentation/admin_routes_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/admin/data/admin_repository.dart',
    ).readAsStringSync();
    final routes = File(
      '${backendRoot.path}/routes/api.php',
    ).readAsStringSync();
    final controller = File(
      '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    for (final label in ['Bieżące', 'Cykliczne', 'Pominięci', 'Archiwum']) {
      expect(mobile, contains(label));
    }
    expect(mobile, contains('ReorderableDragStartListener'));
    expect(mobile, contains('Icons.lock_outline'));
    expect(repository, contains('reassignMissedRoutes'));
    expect(routes, contains('/admin/routes-missed/reassign'));
    expect(controller, contains('function reassignMissedRoutes'));
    expect(controller, contains('missed_route_reassignments'));
    expect(controller, contains("'target_positions'"));
    expect(controller, contains('DeliveryItem::updateOrCreate'));
  });

  test('filtry dokumentów są schowane pod przyciskiem i działają na API', () {
    final mobile = File(
      'lib/src/features/admin/presentation/admin_documents_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/admin/data/admin_repository.dart',
    ).readAsStringSync();
    final controller = File(
      '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(mobile, contains('Filtry dokumentów'));
    expect(mobile, contains('Numer dokumentu, klient lub NIP'));
    expect(mobile, contains('Data od'));
    expect(mobile, contains('Data do'));
    expect(repository, contains("'date_from'"));
    expect(repository, contains("'date_to'"));
    expect(controller, contains("\$request->input('search'"));
    expect(controller, contains("\$request->input('type'"));
  });

  test('statystyki GPS i prywatni klienci są zgodni z panelem WWW', () {
    final screen = File(
      'lib/src/features/admin/presentation/admin_driver_statistics_screen.dart',
    ).readAsStringSync();
    final controller = File(
      '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();
    final myCar = File(
      '${backendRoot.path}/app/Services/MyCarService.php',
    ).readAsStringSync();
    final console = File(
      '${backendRoot.path}/routes/console.php',
    ).readAsStringSync();

    expect(controller, contains('km_delta >= 0 AND km_delta <= 5'));
    expect(controller, isNot(contains('MAX(odometer) - MIN(odometer)')));
    expect(controller, contains("'private_cash_no_recurring_rows'"));
    expect(controller, contains("'private_cash_no_recurring_collected'"));
    expect(screen, contains('Osoby prywatne'));
    expect(screen, contains("stats['private_cash_no_recurring_rows']"));
    expect(console, contains("Schedule::command('wnt:sync-mycar-gps')"));
    expect(myCar, contains('DriverLocation::updateOrCreate'));
    expect(myCar, isNot(contains('DriverLocation::create([')));
  });
}
