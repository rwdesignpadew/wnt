import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin tworzy serwis bez kierowcy i przypisuje go później do trasy', () {
    final screen = File(
      'lib/src/features/admin/presentation/admin_service_requests_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/admin/data/admin_repository.dart',
    ).readAsStringSync();

    expect(screen, contains("'Nowy serwis'"));
    expect(screen, contains('Trasę i kierowcę przypiszesz później.'));
    expect(screen, contains("'Utwórz serwis'"));
    expect(screen, contains("'Przypisz do trasy'"));
    expect(screen, isNot(contains("labelText: 'Kierowca'")));
    expect(repository, contains("_api.post('/mobile/admin/service-requests'"));
    expect(repository, contains("'/mobile/admin/service-requests/\$id/route'"));
  });
}
