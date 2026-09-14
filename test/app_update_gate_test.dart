import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/core/theme/wnt_theme.dart';
import 'package:woda_na_telefon/src/core/update/app_update_gate.dart';

void main() {
  testWidgets('optional update can be dismissed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: WntTheme.light(),
          home: AppUpdateGate(
            loader: () async => const AppUpdateInfo(
              currentBuild: 120,
              latestBuild: 121,
              minimumBuild: 100,
              latestVersion: '1.0.3',
              storeUrl: 'https://example.test/store',
              message: 'Nowa wersja jest gotowa.',
            ),
            child: const Scaffold(body: Text('Aplikacja')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dostępna jest aktualizacja'), findsOneWidget);
    expect(find.text('Później'), findsOneWidget);
    expect(find.text('1.0.3 (121)'), findsOneWidget);

    await tester.tap(find.text('Później'));
    await tester.pumpAndSettle();
    expect(find.text('Dostępna jest aktualizacja'), findsNothing);
  });

  testWidgets('required update cannot be dismissed and opens store', (
    tester,
  ) async {
    Uri? openedUri;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: WntTheme.light(),
          home: AppUpdateGate(
            loader: () async => const AppUpdateInfo(
              currentBuild: 119,
              latestBuild: 121,
              minimumBuild: 120,
              latestVersion: '1.0.3',
              storeUrl: 'https://example.test/store',
              message: 'Ta wersja nie jest już obsługiwana.',
            ),
            storeLauncher: (uri) async {
              openedUri = uri;
              return true;
            },
            child: const Scaffold(body: Text('Aplikacja')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aktualizacja wymagana'), findsOneWidget);
    expect(find.text('Później'), findsNothing);
    await tester.tap(find.text('Aktualizuj'));
    await tester.pumpAndSettle();
    expect(openedUri, Uri.parse('https://example.test/store'));
  });

  test('update policy compares numeric build numbers', () {
    const current = AppUpdateInfo(
      currentBuild: 121,
      latestBuild: 122,
      minimumBuild: 121,
      latestVersion: '1.0.3',
      storeUrl: 'https://example.test/store',
      message: '',
    );
    expect(current.isAvailable, isTrue);
    expect(current.isRequired, isFalse);
  });
}
