import '../../../core/network/api_client.dart';

class ClientRepository {
  const ClientRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> home(String token) {
    return _api.get('/mobile/client/home', token: token);
  }

  Future<Map<String, dynamic>> tracking(String token) {
    return _api.get('/mobile/client/tracking', token: token);
  }

  Future<List<Map<String, dynamic>>> documents(String token) async {
    final response = await _api.get('/mobile/client/documents', token: token);
    return _list(response['documents']);
  }

  Future<Map<String, dynamic>> document(String token, int id) {
    return _api.get('/mobile/client/documents/$id', token: token);
  }

  Future<ApiDownload> documentPdf(String token, int id) {
    return _api.download(
      '/mobile/client/documents/$id/fakturownia',
      token: token,
    );
  }

  Future<ApiDownload> externalDocumentPdf(String token, int id) {
    return _api.download(
      '/mobile/client/external-documents/$id/fakturownia',
      token: token,
    );
  }

  Future<Map<String, dynamic>> createOrder({
    required String token,
    required int? locationId,
    required Map<int, int> quantities,
    String? notes,
  }) {
    return _api.post(
      '/mobile/client/orders',
      token: token,
      body: {
        'client_location_id': ?locationId,
        'quantities': quantities.map(
          (productId, quantity) => MapEntry(productId.toString(), quantity),
        ),
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> data,
  ) {
    return _api.post('/mobile/client/profile', token: token, body: data);
  }

  Future<String> changePassword({
    required String token,
    required String currentPassword,
    required String password,
  }) async {
    final response = await _api.post(
      '/mobile/password/change',
      token: token,
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': password,
      },
    );
    return response['message']?.toString() ?? 'Hasło zostało zmienione.';
  }

  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList()
      : const [];
}
