import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WebView jest ograniczony do bezpiecznego podglądu dokumentu HTML', () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    expect(pubspec, contains('webview_flutter'));

    final webViewFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('WebViewController'))
        .toList();
    expect(webViewFiles, hasLength(1));
    expect(
      webViewFiles.single.path.replaceAll('\\', '/'),
      endsWith('features/documents/presentation/html_document_screen.dart'),
    );
    final source = webViewFiles.single.readAsStringSync();
    expect(source, contains('JavaScriptMode.disabled'));
    expect(source, contains('loadHtmlString(widget.html)'));
    expect(source, isNot(contains('loadRequest(')));
  });

  test('mobilne API nie udostępnia przejścia do sesji webowej', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    expect(routes, isNot(contains('/web-session')));
  });

  test(
    'mapa klienta jest interaktywna, pełnoekranowa i pokazuje strzałkę auta',
    () {
      final source = File(
        'lib/src/features/client/presentation/client_tracking_screen.dart',
      ).readAsStringSync();
      expect(source, contains('initialScrollGesturesEnabled: true'));
      expect(source, contains('initialZoomGesturesEnabled: true'));
      expect(source, contains('initialRotateGesturesEnabled: true'));
      expect(source, contains('initialTiltGesturesEnabled: true'));
      expect(source, contains("tooltip: 'Mapa na pełnym ekranie'"));
      expect(source, contains('class _FullScreenTrackingMap'));
      expect(source, contains('rotation: _heading'));
    },
  );

  test('podglad trasy administratora ma pelna mape, kolejnosc i gesty', () {
    final source = File(
      'lib/src/features/admin/presentation/admin_routes_screen.dart',
    ).readAsStringSync();
    expect(source, contains('class _AdminRouteFullscreenMap'));
    expect(source, contains("tooltip: 'Mapa na pełnym ekranie'"));
    expect(source, contains('initialScrollGesturesEnabled: true'));
    expect(source, contains('initialZoomGesturesEnabled: true'));
    expect(source, contains('initialRotateGesturesEnabled: true'));
    expect(source, contains('initialTiltGesturesEnabled: true'));
    expect(source, contains('_numberedMarker(sequence)'));
    expect(source, contains('roadPath: roadPath'));
    expect(source, contains('LatLngBounds.createBoundsFromPoints'));
    expect(source, contains("Text('Punkty trasy'"));
  });

  test('nawigacja kierowcy prowadzi po calej aktywnej trasie', () {
    final navigation = File(
      'lib/src/features/driver/presentation/driver_navigation_screen.dart',
    ).readAsStringSync();
    final route = File(
      'lib/src/features/driver/presentation/driver_route_screen.dart',
    ).readAsStringSync();
    expect(navigation, contains('waypoints: widget.destinations'));
    expect(navigation, contains('GoogleMapsNavigator.setDestinations'));
    expect(navigation, contains('continueToNextDestination'));
    expect(navigation, contains('followMyLocation(CameraPerspective.tilted)'));
    expect(route, contains("document['status'] != 'missed_closed'"));
    expect(route, contains('!_isServed(document)'));
    expect(route, contains('isSkipped:'));
    expect(route, contains("'Pominięty — wymaga obsługi'"));
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
