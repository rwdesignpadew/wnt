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
    expect(repository, contains("'source'"));
    expect(repository, contains("'client_id'"));
    expect(repository, contains("'client_type'"));
    expect(repository, contains("'driver_id'"));
    expect(controller, contains("\$request->input('search'"));
    expect(controller, contains("\$request->input('type'"));
    expect(mobile, contains('Kierowca / wystawca'));
    expect(mobile, contains('Osoby prywatne'));
  });

  test('miesięczne WZ są ustawiane przy klientach, a nie w dokumentach', () {
    final documents = File(
      'lib/src/features/admin/presentation/admin_documents_screen.dart',
    ).readAsStringSync();
    final clients = File(
      'lib/src/features/admin/presentation/admin_clients_screen.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/src/features/admin/presentation/admin_monthly_wz_summary_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/admin/data/admin_repository.dart',
    ).readAsStringSync();
    final controller = File(
      '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();
    final fakturownia = File(
      '${backendRoot.path}/app/Services/FakturowniaService.php',
    ).readAsStringSync();

    expect(documents, isNot(contains('Miesięczne podsumowanie WZ')));
    expect(clients, contains('WZ do faktur miesięcznych'));
    expect(summary, contains('WZ do faktur miesięcznych'));
    expect(summary, isNot(contains('Co kupili wszyscy')));
    expect(summary, isNot(contains('Zakupy klientów prywatnych')));
    expect(summary, contains('Wystawione WZ'));
    expect(summary, contains('documentPdf'));
    expect(summary, contains('Wyślij wszystkie WZ razem z Fakturą VAT'));
    expect(repository, contains('monthlyWzSummary'));
    expect(repository, contains('updateMonthlyWzEmailPreference'));
    expect(controller, contains('function monthlyWzSummary'));
    expect(fakturownia, contains('sendInvoiceWithWarehouseDocumentsEmail'));
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
    expect(screen, contains('Zakupy klientów prywatnych'));
    expect(screen, contains('Klienci i kupione produkty'));
    expect(screen, isNot(contains('Co kupiły firmy')));
    expect(screen, isNot(contains('Co kupiły osoby prywatne')));
    expect(screen, contains("stats['private_cash_no_recurring_rows']"));
    expect(
      controller,
      contains(r'! (bool) $document->customer_requests_invoice'),
    );
    expect(controller, contains(r'blank($document->final_invoice_number)'));
    expect(console, contains("Schedule::command('wnt:sync-mycar-gps')"));
    expect(myCar, contains('DriverLocation::updateOrCreate'));
    expect(myCar, isNot(contains('DriverLocation::create([')));
  });

  test('zakładki są niebieskie jak w Dokumentach, bez zielonych chipów', () {
    final tabs = File(
      'lib/src/shared/widgets/wnt_filter_tabs.dart',
    ).readAsStringSync();
    final driverStats = File(
      'lib/src/features/admin/presentation/admin_driver_statistics_screen.dart',
    ).readAsStringSync();
    final clientStats = File(
      'lib/src/features/admin/presentation/admin_client_stats_screen.dart',
    ).readAsStringSync();

    expect(tabs, contains('selected ? WntColors.brand'));
    expect(tabs, contains('selected ? Colors.white : WntColors.text'));
    expect(driverStats, contains('WntFilterTabs<String>'));
    expect(driverStats, isNot(contains('ChoiceChip(')));
    expect(clientStats, contains('WntFilterTabs<String>'));
  });

  test('klient może zamówić sanityzację z limitem lokalizacji', () {
    final screen = File(
      'lib/src/features/client/presentation/client_service_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/client/data/client_repository.dart',
    ).readAsStringSync();
    final routes = File(
      '${backendRoot.path}/routes/api.php',
    ).readAsStringSync();
    final controller = File(
      '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileClientController.php',
    ).readAsStringSync();
    final service = File(
      '${backendRoot.path}/app/Services/ClientSanitizationRequestService.php',
    ).readAsStringSync();

    expect(screen, contains('Sanityzacje na żądanie'));
    expect(screen, contains('max_dispenser_count'));
    expect(screen, contains('Zamów sanityzację'));
    expect(repository, contains('/mobile/client/sanitizations'));
    expect(routes, contains("/client/sanitizations'"));
    expect(controller, contains('function storeSanitization'));
    expect(service, contains("'is_on_request' => true"));
    expect(service, contains('Wybierz od 1 do '));
    expect(service, contains('jest już otwarte zgłoszenie'));
  });

  test('nowa dzierżawa oddziela pierwszą opłatę od kolejnych miesięcy', () {
    final rentals = File(
      'lib/src/features/admin/presentation/admin_management_screens.dart',
    ).readAsStringSync();
    final clients = File(
      'lib/src/features/admin/presentation/admin_client_full_edit_screen.dart',
    ).readAsStringSync();
    final controller = File(
      '${backendRoot.path}/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();
    final completion = File(
      '${backendRoot.path}/app/Services/DeliveryDocumentCompletionService.php',
    ).readAsStringSync();

    expect(rentals, contains('Pobrano opłatę za dzierżawę'));
    expect(rentals, contains("'initial_fee_collected': initialFeeCollected"));
    expect(rentals, contains("'requires_sanitization': requiresSanitization"));
    expect(rentals, isNot(contains("'recurring_billing': recurring")));
    expect(
      controller,
      contains("'initial_fee_collected' => ['nullable', 'boolean']"),
    );
    expect(
      controller,
      isNot(contains("LOWER(name) LIKE ?', ['%dystrybutor%']")),
    );
    expect(completion, contains(r'$rental->recurring_billing = true'));
    expect(completion, contains('rentalInitialFeeCollected'));
    expect(clients, contains('Wyślij fakturę ze wszystkimi WZ z miesiąca'));
    expect(clients, contains("'email_monthly_wz_with_invoice'"));
  });
}
