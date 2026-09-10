import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:woda_na_telefon/src/core/network/api_client.dart';
import 'package:woda_na_telefon/src/core/storage/offline_store.dart';
import 'package:woda_na_telefon/src/features/driver/data/driver_repository.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'wnt-driver-sanitization-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('zapis WZ wysyła sanityzację w tej samej operacji', () async {
    late Map<String, dynamic> body;
    final repository = DriverRepository(
      ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            endsWith('/mobile/driver/documents/41/complete'),
          );
          body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
          return http.Response(
            jsonEncode({
              'document': {'id': 41},
            }),
            200,
          );
        }),
      ),
      OfflineStore(supportDirectory: () async => directory),
    );

    await repository.complete(
      token: 'token',
      userId: 7,
      documentId: 41,
      quantities: const {},
      paymentMethod: 'cash',
      signatureData: 'data:image/png;base64,dGVzdA==',
      signedBy: 'Odbiorca',
      sanitizationSelected: true,
      sanitizationId: 91,
      sanitizationCompletedDispenserCount: 2,
      sanitizationNextIntervalDays: 180,
      sanitizationResultNotes: 'Wykonano dwa urządzenia',
    );

    expect(body['quantities'], isEmpty);
    expect(body['sanitization_selected'], isTrue);
    expect(body['sanitization_id'], 91);
    expect(body['sanitization_completed_dispenser_count'], 2);
    expect(body['sanitization_next_interval_days'], 180);
    expect(body['sanitization_result_notes'], 'Wykonano dwa urządzenia');
  });

  test('podgląd WZ również zawiera wybraną sanityzację', () async {
    late Map<String, dynamic> body;
    final repository = DriverRepository(
      ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            endsWith('/mobile/driver/documents/52/completion-preview'),
          );
          expect(request.url.queryParameters['type'], 'wz');
          body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
          return http.Response.bytes(
            utf8.encode('%PDF-1.7\n%%EOF'),
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      ),
      OfflineStore(supportDirectory: () async => directory),
    );

    await repository.completionPreview(
      token: 'token',
      documentId: 52,
      quantities: const {},
      paymentMethod: 'transfer',
      signatureData: 'data:image/png;base64,dGVzdA==',
      signedBy: 'Odbiorca',
      sanitizationSelected: true,
      sanitizationId: 92,
      sanitizationCompletedDispenserCount: 3,
      sanitizationNextIntervalDays: 180,
      sanitizationResultNotes: 'Wszystkie wykonane',
    );

    expect(body['sanitization_selected'], isTrue);
    expect(body['sanitization_id'], 92);
    expect(body['sanitization_completed_dispenser_count'], 3);
  });
}
