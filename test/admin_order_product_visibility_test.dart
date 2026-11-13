import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/core/network/api_client.dart';
import 'package:woda_na_telefon/src/core/notifications/push_notification_service.dart';
import 'package:woda_na_telefon/src/core/storage/session_store.dart';
import 'package:woda_na_telefon/src/core/theme/wnt_theme.dart';
import 'package:woda_na_telefon/src/features/admin/application/admin_providers.dart';
import 'package:woda_na_telefon/src/features/admin/data/admin_repository.dart';
import 'package:woda_na_telefon/src/features/admin/presentation/admin_more_screen.dart';
import 'package:woda_na_telefon/src/features/auth/application/auth_controller.dart';
import 'package:woda_na_telefon/src/features/auth/data/auth_repository.dart';
import 'package:woda_na_telefon/src/features/auth/domain/app_session.dart';
import 'package:woda_na_telefon/src/shared/widgets/quantity_stepper.dart';

class _TestAuthController extends AuthController {
  _TestAuthController()
    : super(
        AuthRepository(ApiClient(), SessionStore()),
        PushNotificationService(ApiClient()),
      ) {
    state = const AuthState.signedIn(
      AppSession(
        token: 'test-token',
        user: AppUser(
          id: 1,
          name: 'Administrator',
          email: 'admin@example.test',
          role: UserRole.admin,
        ),
      ),
    );
  }

  @override
  Future<void> restore() async {}
}

class _TestAdminRepository extends AdminRepository {
  _TestAdminRepository() : super(ApiClient());

  @override
  Future<Map<String, dynamic>> routeOptions(String token) async => {
    'products': [
      {'id': 11, 'name': 'Produkt przypisany', 'unit': 'szt.'},
      {'id': 12, 'name': 'Produkt dodatkowy', 'unit': 'szt.'},
    ],
    'clients': [
      {
        'id': 101,
        'name': 'Klient testowy',
        'visible_product_ids': [11],
        'locations': [
          {
            'id': 1001,
            'name': 'Siedziba',
            'address': 'Testowa 1',
            'is_default': true,
            'visible_product_ids': [11],
          },
        ],
      },
      {
        'id': 102,
        'name': 'Inny odbiorca',
        'visible_product_ids': [12],
        'locations': [
          {
            'id': 1002,
            'name': 'Magazyn',
            'address': 'Przemysłowa 2',
            'is_default': true,
            'visible_product_ids': [12],
          },
        ],
      },
    ],
  };
}

void main() {
  testWidgets(
    'nowe zamowienie pokazuje najpierw produkty klienta, a reszte po rozwinieciu',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            adminRepositoryProvider.overrideWithValue(_TestAdminRepository()),
            adminOperationsProvider.overrideWith(
              (ref) async => {
                'orders': <Map<String, dynamic>>[],
                'route_options': <Map<String, dynamic>>[],
              },
            ),
          ],
          child: MaterialApp(
            theme: WntTheme.light(),
            home: const AdminOperationsScreen(
              dataKey: 'orders',
              title: 'Zamowienia',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Nowe zamówienie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wyszukaj klienta'));
      await tester.pumpAndSettle();
      expect(find.text('Klient testowy'), findsOneWidget);
      expect(find.text('Inny odbiorca'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Wpisz nazwę klienta, NIP lub adres'),
        'Testowa 1',
      );
      await tester.pump();
      expect(find.text('Klient testowy'), findsOneWidget);
      expect(find.text('Inny odbiorca'), findsNothing);

      await tester.tap(find.text('Klient testowy'));
      await tester.pumpAndSettle();

      expect(find.text('Produkt przypisany'), findsOneWidget);
      expect(find.text('Produkt dodatkowy'), findsNothing);
      expect(find.text('Pokaż więcej produktów (1)'), findsOneWidget);
      final quantityField = find.descendant(
        of: find.byType(QuantityStepper),
        matching: find.byType(TextField),
      );
      expect(quantityField, findsOneWidget);
      await tester.enterText(quantityField, '25');
      await tester.pump();
      expect(tester.widget<TextField>(quantityField).controller?.text, '25');

      await tester.tap(find.text('Pokaż więcej produktów (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Produkt przypisany'), findsOneWidget);
      expect(find.text('Produkt dodatkowy'), findsOneWidget);
      expect(find.text('Pokaż mniej produktów'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
