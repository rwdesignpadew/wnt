import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/core/network/api_client.dart';
import 'package:woda_na_telefon/src/core/notifications/push_notification_service.dart';
import 'package:woda_na_telefon/src/core/storage/session_store.dart';
import 'package:woda_na_telefon/src/core/theme/wnt_theme.dart';
import 'package:woda_na_telefon/src/features/admin/application/admin_providers.dart';
import 'package:woda_na_telefon/src/features/admin/data/admin_repository.dart';
import 'package:woda_na_telefon/src/features/admin/presentation/admin_route_edit_screen.dart';
import 'package:woda_na_telefon/src/features/auth/application/auth_controller.dart';
import 'package:woda_na_telefon/src/features/auth/data/auth_repository.dart';
import 'package:woda_na_telefon/src/features/auth/domain/app_session.dart';

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

  Map<String, dynamic>? savedBody;

  @override
  Future<Map<String, dynamic>> routeOptions(String token) async => {
    'drivers': [
      {'id': 7, 'name': 'Kamil Kierowca'},
    ],
    'regions': [
      {'slug': 'mielec', 'name': 'Mielec'},
      {'slug': 'tuszow', 'name': 'Tuszów'},
    ],
    'products': [
      {
        'id': 11,
        'name': 'Woda Źródlana 18,9 l',
        'unit': 'szt.',
        'default_price': 16,
      },
    ],
    'clients': [
      {
        'id': 101,
        'name': 'Bardzo długa nazwa klienta testowego spółka z o.o.',
        'visible_product_ids': [11],
        'prices': <String, dynamic>{},
        'locations': [
          {
            'id': 1001,
            'name': 'Główna lokalizacja',
            'address': 'Długa 123, 39-300 Mielec',
            'region': 'Mielec',
            'is_default': true,
            'visible_product_ids': [11],
            'prices': <String, dynamic>{},
            'packages': <dynamic>[],
            'sanitization': <String, dynamic>{},
          },
        ],
      },
      {
        'id': 102,
        'name': 'Drugi klient',
        'visible_product_ids': [11],
        'prices': <String, dynamic>{},
        'locations': [
          {
            'id': 1002,
            'name': 'Magazyn i hala produkcyjna',
            'address': 'Przemysłowa 45, 39-332 Tuszów Narodowy',
            'region': 'Tuszów',
            'is_default': true,
            'visible_product_ids': [11],
            'prices': <String, dynamic>{},
            'packages': <dynamic>[],
            'sanitization': <String, dynamic>{},
          },
        ],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> saveRoute(
    String token,
    int? id,
    Map<String, dynamic> body,
  ) async {
    savedBody = body;
    return {'message': 'Trasa została zapisana.'};
  }
}

void main() {
  testWidgets(
    'natywny edytor trasy mieści się na małym ekranie i dodaje wiele lokalizacji',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _TestAdminRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            adminRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: WntTheme.light(),
            home: const AdminRouteEditScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ustawienia'), findsWidgets);
      expect(find.text('Punkty (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nazwa trasy'),
        'Trasa testowa',
      );
      await tester.tap(find.text('Dalej: punkty (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Dodaj punkty'));
      await tester.pumpAndSettle();

      expect(find.text('Dodaj punkty do trasy'), findsOneWidget);
      expect(find.textContaining('Bardzo długa nazwa'), findsOneWidget);
      expect(find.text('Drugi klient'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('Bardzo długa nazwa'));
      await tester.pump();
      await tester.tap(find.text('Drugi klient'));
      await tester.pump();
      await tester.tap(find.text('Dodaj 2'));
      await tester.pumpAndSettle();

      expect(find.text('Punkty (2)'), findsOneWidget);
      expect(find.textContaining('Bardzo długa nazwa'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsWidgets);
      await tester.tap(find.textContaining('Bardzo długa nazwa'));
      await tester.pumpAndSettle();
      expect(find.text('Ustaw wydanie'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.textContaining('Bardzo długa nazwa'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(find.text('Drugi klient'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Zapisz trasę · 2 pkt'));
      await tester.pumpAndSettle();
      expect(repository.savedBody?['name'], 'Trasa testowa');
      expect(repository.savedBody?['stops'], hasLength(2));
      expect(
        (repository.savedBody?['stops'] as List)
            .map((item) => item['location_id'])
            .toList(),
        [1001, 1002],
      );
    },
  );
}
