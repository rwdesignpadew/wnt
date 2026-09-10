import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/features/driver/presentation/driver_documents_screen.dart';

void main() {
  test('adds a separate PZ row for a WZ with recorded returns', () {
    final rows = driverDocumentRows([
      {
        'id': 1747,
        'number': 'WZ2283',
        'has_return_pz': true,
        'pz_number': 'PZ216',
        'sort_at': 100,
      },
    ]);

    expect(rows, hasLength(2));
    expect(rows.map((row) => row['type']), ['wz', 'pz']);
    expect(rows.map((row) => row['number']), ['WZ2283', 'PZ216']);
  });

  test('does not invent a PZ row when there was no return', () {
    final rows = driverDocumentRows([
      {
        'id': 1748,
        'number': 'WZ2284',
        'has_return_pz': false,
        'pz_number': null,
        'sort_at': 101,
      },
    ]);

    expect(rows, hasLength(1));
    expect(rows.single['type'], 'wz');
  });
}
