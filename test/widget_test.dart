import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:woda_na_telefon/src/core/theme/wnt_theme.dart';
import 'package:woda_na_telefon/src/features/admin/application/admin_providers.dart';
import 'package:woda_na_telefon/src/features/admin/presentation/admin_clients_screen.dart';
import 'package:woda_na_telefon/src/features/admin/presentation/admin_more_screen.dart';
import 'package:woda_na_telefon/src/features/admin/presentation/admin_routes_screen.dart';
import 'package:woda_na_telefon/src/features/client/application/client_providers.dart';
import 'package:woda_na_telefon/src/features/client/presentation/client_order_screen.dart';
import 'package:woda_na_telefon/src/features/driver/presentation/driver_service_screen.dart';
import 'package:woda_na_telefon/src/shared/widgets/auth_frame.dart';

void main() {
  testWidgets(
    'prywatny klient płaci netto, a checkbox faktury przełącza cenę na brutto',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: WntTheme.light(),
            home: DriverServiceScreen(
              document: {
                'id': 1,
                'status': 'planned',
                'is_company': false,
                'payment_method': 'cash',
                'debt_amount': 20,
                'credit_amount': 5,
                'available_product_ids': [1],
                'items': [
                  {'product_id': 1, 'quantity': 1},
                ],
                'client': {
                  'name': 'Klient prywatny',
                  'recurring_invoice_enabled': false,
                },
              },
              products: const [
                {
                  'id': 1,
                  'name': 'Woda testowa',
                  'unit': 'szt.',
                  'default_price': 100,
                  'vat_rate': 23,
                  'kind': 'product',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Klient chce fakturę VAT'), findsOneWidget);
      expect(find.text('Cena do zapłaty: 100.00 zł'), findsOneWidget);
      expect(find.text('115.00 zł'), findsOneWidget);

      await tester.tap(find.text('Klient chce fakturę VAT'));
      await tester.pumpAndSettle();
      expect(find.text('Cena do zapłaty: 123.00 zł'), findsOneWidget);
      expect(find.text('138.00 zł'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('bieżące trasy mają dzisiejszą datę przed przyszłymi', () {
    final source = File(
      'lib/src/features/admin/presentation/admin_routes_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      contains("_int(a['sort_at']).compareTo(_int(b['sort_at']))"),
    );
    expect(
      source,
      contains("_int(b['sort_at']).compareTo(_int(a['sort_at']))"),
    );
  });

  test('podstrony Więcej zachowują header i dolne menu administratora', () {
    final source = File(
      'lib/src/features/admin/presentation/admin_more_screen.dart',
    ).readAsStringSync();
    expect(source, contains("const Text('Woda na telefon')"));
    expect(source, contains('homeNavigationIndexProvider'));
    expect(source, contains('bottomNavigationBar: _adminNestedNavigation'));
    expect(source, contains("label: 'Start'"));
    expect(source, contains("label: 'Więcej'"));
  });
  testWidgets('ekran uwierzytelniania mieści logo i polskie teksty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WntTheme.light(),
        home: const AuthFrame(
          title: 'Zaloguj się',
          subtitle: 'Woda na telefon',
          child: Text('Załóż konto klienta'),
        ),
      ),
    );

    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Załóż konto klienta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'klienci mają zakładki aktywni i nieaktywni oraz szybkie akcje bez overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminClientsProvider.overrideWith(
              (ref) async => [
                {
                  'id': 1,
                  'title': 'Aktywny klient',
                  'subtitle': 'Adres aktywnego klienta',
                  'meta': 'aktywny@example.test',
                  'status': 'aktywny',
                },
                {
                  'id': 2,
                  'title': 'Nieaktywny klient',
                  'subtitle': 'Adres nieaktywnego klienta',
                  'meta': 'nieaktywny@example.test',
                  'status': 'wylaczony',
                },
              ],
            ),
          ],
          child: MaterialApp(
            theme: WntTheme.light(),
            home: const Scaffold(body: AdminClientsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aktywni (1)'), findsOneWidget);
      expect(find.text('Nieaktywni (1)'), findsOneWidget);
      expect(find.text('Aktywny klient'), findsOneWidget);
      expect(find.text('Edytuj'), findsOneWidget);
      expect(find.text('Produkty'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Nieaktywni (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Nieaktywny klient'), findsOneWidget);
      expect(find.text('Aktywny klient'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opóźnione zamówienie otwiera pełny popup z kwotą i zamknięciem bez overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminOperationsProvider.overrideWith(
              (ref) async => {
                'orders': [
                  {
                    'id': 2,
                    'title': 'ZAM/TEST/2',
                    'subtitle': 'Klient testowy',
                    'meta': 'Siedziba firmy · 662,85 zł',
                    'status': 'overdue',
                    'display_status': 'overdue',
                    'is_overdue': true,
                    'route_id': null,
                    'location': 'Siedziba firmy',
                    'address': 'Testowa 2',
                    'total_gross': 662.85,
                    'items': [
                      {'name': 'Butla 18,9L', 'quantity': 5, 'unit': 'szt.'},
                    ],
                  },
                ],
                'route_options': <Map<String, dynamic>>[],
              },
            ),
          ],
          child: MaterialApp(
            theme: WntTheme.light(),
            home: const AdminOperationsScreen(
              dataKey: 'orders',
              title: 'Zamówienia',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ZAM/TEST/2'));
      await tester.pumpAndSettle();

      expect(find.text('Razem brutto'), findsOneWidget);
      expect(find.text('662,85 zł'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Razem brutto'), findsNothing);
    },
  );

  testWidgets(
    'formularz klienta pojawia się dopiero po Nowe zamówienie i nie ma overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientHomeProvider.overrideWith(
              (ref) async => {
                'products': [
                  {
                    'id': 1,
                    'name': 'WYSOWIANKA WIELOOWOCOWA 0,3L (24 szt)',
                    'default_price': 24.39,
                    'unit': 'szt.',
                  },
                ],
                'locations': [
                  {'id': 1, 'is_default': true},
                ],
                'orders': [
                  {
                    'id': 1,
                    'number': 'ZAM/202608/0001',
                    'status': 'overdue',
                    'total_gross': 662.85,
                    'created_at': '20.08.2026 09:44',
                  },
                ],
              },
            ),
            clientTrackingProvider.overrideWith(
              (ref) async => {'tracking': null},
            ),
          ],
          child: MaterialApp(
            theme: WntTheme.light(),
            home: const Scaffold(body: ClientOrderScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WYSOWIANKA WIELOOWOCOWA 0,3L (24 szt)'), findsNothing);
      expect(find.text('Nowe zamówienie'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ZAM/202608/0001'));
      await tester.pumpAndSettle();
      expect(find.text('Razem brutto'), findsOneWidget);
      expect(find.text('662,85 zł'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nowe zamówienie'));
      await tester.pumpAndSettle();

      expect(
        find.text('WYSOWIANKA WIELOOWOCOWA 0,3L (24 szt)'),
        findsOneWidget,
      );
      expect(find.text('Wyślij zamówienie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'trasy bieżące zaczynają się od dzisiejszej, archiwum od najnowszej',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminRoutesProvider.overrideWith(
              (ref) async => [
                {
                  'id': 3,
                  'title': 'Przyszła',
                  'subtitle': '04.09.2026',
                  'meta': '2 pkt',
                  'sort_at': 1788472800,
                  'is_archived': false,
                },
                {
                  'id': 1,
                  'title': 'Archiwalna starsza',
                  'subtitle': '20.08.2026',
                  'meta': '2 pkt',
                  'sort_at': 1787176800,
                  'is_archived': true,
                },
                {
                  'id': 4,
                  'title': 'Dzisiejsza',
                  'subtitle': '23.08.2026',
                  'meta': '3 pkt',
                  'sort_at': 1787436000,
                  'is_archived': false,
                },
                {
                  'id': 2,
                  'title': 'Archiwalna najnowsza',
                  'subtitle': '22.08.2026',
                  'meta': '4 pkt',
                  'sort_at': 1787349600,
                  'is_archived': true,
                },
              ],
            ),
          ],
          child: MaterialApp(
            theme: WntTheme.light(),
            home: const Scaffold(body: AdminRoutesScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Dzisiejsza')).dy,
        lessThan(tester.getTopLeft(find.text('Przyszła')).dy),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Archiwalne'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Archiwalna najnowsza')).dy,
        lessThan(tester.getTopLeft(find.text('Archiwalna starsza')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
