import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/features/admin/domain/rental_sanitization_rules.dart';

void main() {
  test('dystrybutory i misy ceramiczne wymagają sanityzacji', () {
    expect(rentalProductRequiresSanitization('Dystrybutor wody'), isTrue);
    expect(rentalProductRequiresSanitization('Misa ceramiczna'), isTrue);
    expect(
      rentalProductRequiresSanitization('Dzierżawa Misa ceramiczna'),
      isTrue,
    );
  });

  test('stojaki i pompki nie wymagają automatycznej sanityzacji', () {
    expect(rentalProductRequiresSanitization('Stojak pod misę'), isFalse);
    expect(rentalProductRequiresSanitization('Pompka do wody'), isFalse);
  });
}
