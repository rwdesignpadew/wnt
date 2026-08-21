import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aplikacja nie zawiera WebView', () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    expect(pubspec, isNot(contains('webview')));

    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n')
        .toLowerCase();
    expect(source, isNot(contains('webview')));
  });

  test('mobilne API nie udostępnia przejścia do sesji webowej', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    expect(routes, isNot(contains('/web-session')));
  });

  test('źródła nie zawierają typowych śladów uszkodzonego UTF-8', () {
    const forbidden = ['Ã', 'Ä', 'Å', 'Â', 'Ă', 'Ĺ', '�'];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final marker in forbidden) {
        expect(
          source.contains(marker),
          isFalse,
          reason: '${file.path} zawiera uszkodzony znak $marker',
        );
      }
    }
  });
}
