import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/features/driver/domain/driver_product_classification.dart';

void main() {
  group('isDriverReturnItem', () {
    test('recognizes explicit API return flag', () {
      expect(isDriverReturnItem({'is_return_container': true}), isTrue);
    });

    test('recognizes return stock names without word zwrot', () {
      for (final name in [
        'Transporter Wysowianka',
        'Transtorter Wysowianka',
        'Butelka Wysowianka 0,3L',
        'Butelka Wysowianka 0.3L',
      ]) {
        expect(isDriverReturnItem({'product_name': name}), isTrue);
      }
    });

    test('recognizes all explicit return categories', () {
      for (final name in [
        'Zwrot butli 18,9L',
        'Zwrot butelek 0,3L',
        'Zwrot transportera',
        'Zwrot palety Euro',
        'Zwrot dystrybutora',
        'Zwrot stojaka',
        'Zwrot pompki',
      ]) {
        expect(isDriverReturnItem({'product_name': name}), isTrue);
      }
    });

    test('does not classify delivered products as returns', () {
      for (final name in [
        'Woda Źródlana 18,9L',
        'WYSOWIANKA Kiwi 0,3L (24 szt)',
        'Paleta Euro - sprzedaż',
      ]) {
        expect(isDriverReturnItem({'product_name': name}), isFalse);
      }
    });

    test('does not classify distributors as bottle returns', () {
      for (final name in [
        'Dystrybutor wody',
        'Dystrybutor nablatowy',
        'Dystrybutor wody GAZUJĄCY',
      ]) {
        final product = {'product_name': name};
        expect(isDriverRentalEquipment(product), isTrue);
        expect(isDriverReturnItem(product), isFalse);
      }
    });
  });
}
