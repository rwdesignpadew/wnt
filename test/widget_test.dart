import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:woda_na_telefon/src/core/theme/wnt_theme.dart';
import 'package:woda_na_telefon/src/shared/widgets/auth_frame.dart';

void main() {
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
}
