import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:woda_na_telefon/src/core/network/api_client.dart';
import 'package:woda_na_telefon/src/core/network/api_exception.dart';

void main() {
  test('dekoduje polskie znaki z odpowiedzi UTF-8', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Załóż konto i zamów wodę'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    final response = await client.get('/test');
    expect(response['message'], 'Załóż konto i zamów wodę');
  });

  test('nie zamienia strony logowania w odpowiedź API', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async =>
            http.Response('<!DOCTYPE html><title>Logowanie</title>', 200),
      ),
    );

    expect(() => client.get('/test'), throwsA(isA<ApiException>()));
  });

  test('odrzuca odpowiedź udającą PDF', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('<!DOCTYPE html><title>Logowanie</title>'),
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      ),
    );

    expect(
      () => client.download('/document', token: 'token'),
      throwsA(isA<ApiException>()),
    );
  });

  test('przyjmuje firmowy podgląd PZ mimo błędnego typu PDF', () async {
    const html = '''<!DOCTYPE html>
<html><body><div class="invoice-shell" id="invoiceShell">
<main class="invoice" id="invoiceDocument">
<h1>Przyjęcie zewnętrzne (PZ) Nr PZ109</h1>
</main></div></body></html>''';
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(html),
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      ),
    );

    final download = await client.download('/document', token: 'token');
    expect(download.contentType, startsWith('text/html'));
    expect(utf8.decode(download.bytes), contains('invoiceDocument'));
  });

  test('przyjmuje prawidłową sygnaturę PDF', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('%PDF-1.7\n%%EOF'),
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-disposition': 'inline; filename="WZ1836.pdf"',
          },
        ),
      ),
    );

    final download = await client.download('/document', token: 'token');
    expect(download.filename, 'WZ1836.pdf');
    expect(utf8.decode(download.bytes), startsWith('%PDF'));
  });

  test('wysyła dane POST przy generowaniu podglądu PDF', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer token');
        expect(jsonDecode(request.body), {
          'quantities': {'70': 3},
        });
        return http.Response.bytes(
          utf8.encode('%PDF-1.7\n%%EOF'),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
    );

    final download = await client.download(
      '/document-preview',
      token: 'token',
      body: {
        'quantities': {'70': 3},
      },
    );
    expect(download.contentType, 'application/pdf');
  });
}
