import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/shared/widgets/wnt_searchable_select.dart';

void main() {
  testWidgets('wyszukiwany wybór filtruje klientów i zwraca wskazany rekord', (
    tester,
  ) async {
    var selectedId = 0;
    const clients = [
      {'id': 1, 'name': 'Alfa', 'address': 'Mielec'},
      {'id': 2, 'name': 'Beta', 'address': 'Tarnobrzeg'},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: WntSearchableSelectField(
                label: 'Klient',
                hintText: 'Wyszukaj klienta',
                onTap: () async {
                  final selected =
                      await showWntSearchPicker<Map<String, Object>>(
                        context: context,
                        title: 'Wybierz klienta',
                        searchHint: 'Wpisz nazwę klienta lub adres',
                        items: clients,
                        titleFor: (item) => '${item['name']}',
                        subtitleFor: (item) => '${item['address']}',
                        searchTextFor: (item) =>
                            '${item['name']} ${item['address']}',
                      );
                  selectedId = selected?['id'] as int? ?? 0;
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Wyszukaj klienta'));
    await tester.pumpAndSettle();
    expect(find.text('Alfa'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Tarnobrzeg');
    await tester.pump();
    expect(find.text('Alfa'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(selectedId, 2);
  });
}
