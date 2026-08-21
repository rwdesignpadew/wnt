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
}
