import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiDownload {
  const ApiDownload({
    required this.bytes,
    required this.contentType,
    required this.filename,
  });

  final Uint8List bytes;
  final String contentType;
  final String filename;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) {
    return send('GET', path, token: token, query: query);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) {
    return send('POST', path, token: token, body: body);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) {
    return send('PUT', path, token: token, body: body);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) {
    return send('PATCH', path, token: token, body: body);
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) {
    return send('DELETE', path, token: token);
  }

  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    String? token,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(_headers(token));
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _client
          .send(request)
          .timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = _decodeJson(response.bodyBytes, response.statusCode);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exception(decoded, response.statusCode);
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException('Serwer nie odpowiedział w wymaganym czasie.');
    } on http.ClientException {
      throw const ApiException('Brak połączenia z serwerem Woda na telefon.');
    }
  }

  Future<ApiDownload> download(String path, {required String token}) async {
    try {
      final response = await _client
          .get(
            _uri(path),
            headers: {
              ..._headers(token),
              'Accept':
                  'application/pdf, application/octet-stream, application/json',
            },
          )
          .timeout(AppConfig.requestTimeout);
      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exception(
          _decodeJson(response.bodyBytes, response.statusCode),
          response.statusCode,
        );
      }
      final isPdf = contentType.contains('pdf');
      final isHtml = contentType.contains('text/html');
      if (!isPdf && !isHtml) {
        throw const ApiException('Serwer nie zwrócił prawidłowego pliku PDF.');
      }
      if (isHtml) {
        return ApiDownload(
          bytes: response.bodyBytes,
          contentType: contentType,
          filename: _filename(response.headers['content-disposition']),
        );
      }
      const pdfSignature = [0x25, 0x50, 0x44, 0x46];
      if (response.bodyBytes.length < pdfSignature.length ||
          !List.generate(
            pdfSignature.length,
            (index) => response.bodyBytes[index] == pdfSignature[index],
          ).every((matches) => matches)) {
        throw const ApiException(
          'Pobrany dokument nie jest prawidłowym plikiem PDF.',
        );
      }
      return ApiDownload(
        bytes: response.bodyBytes,
        contentType: contentType,
        filename: _filename(response.headers['content-disposition']),
      );
    } on TimeoutException {
      throw const ApiException('Pobieranie dokumentu trwało zbyt długo.');
    } on http.ClientException {
      throw const ApiException('Nie udało się pobrać dokumentu.');
    }
  }

  Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '${AppConfig.apiBaseUrl}$normalized',
    ).replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeJson(Uint8List bytes, int statusCode) {
    if (bytes.isEmpty) return <String, dynamic>{};
    final text = utf8.decode(bytes, allowMalformed: false);
    if (text.trimLeft().startsWith('<')) {
      throw ApiException(
        statusCode >= 500
            ? 'Serwer zgłosił błąd wewnętrzny.'
            : 'Serwer zwrócił nieprawidłową odpowiedź.',
        statusCode: statusCode,
      );
    }
    final value = jsonDecode(text);
    if (value is! Map) {
      throw ApiException(
        'Nieprawidłowy format odpowiedzi API.',
        statusCode: statusCode,
      );
    }
    return value.cast<String, dynamic>();
  }

  ApiException _exception(Map<String, dynamic> json, int statusCode) {
    final rawErrors = json['errors'];
    final errors = <String, List<String>>{};
    if (rawErrors is Map) {
      for (final entry in rawErrors.entries) {
        final value = entry.value;
        errors[entry.key.toString()] = value is List
            ? value.map((item) => item.toString()).toList()
            : [value.toString()];
      }
    }
    return ApiException(
      json['message']?.toString().trim().isNotEmpty == true
          ? json['message'].toString()
          : 'Operacja nie powiodła się.',
      statusCode: statusCode,
      errors: errors,
    );
  }

  String _filename(String? disposition) {
    if (disposition == null) return 'dokument.pdf';
    return RegExp('filename="?([^";]+)').firstMatch(disposition)?.group(1) ??
        'dokument.pdf';
  }
}
