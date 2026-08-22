import '../../../core/network/api_client.dart';

class AdminRepository {
  const AdminRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> summary(String token) =>
      _api.get('/mobile/admin/summary', token: token);
  Future<Map<String, dynamic>> operations(String token) =>
      _api.get('/mobile/admin/operations', token: token);
  Future<Map<String, dynamic>> updateOrderStatus(
    String token,
    int id,
    String status,
  ) => _api.post(
    '/mobile/admin/orders/$id/status',
    token: token,
    body: {'status': status},
  );
  Future<Map<String, dynamic>> assignOrderRoute(
    String token,
    int id,
    int? routeId,
  ) => _api.post(
    '/mobile/admin/orders/$id/route',
    token: token,
    body: {'delivery_route_id': routeId},
  );
  Future<Map<String, dynamic>> completeSanitization(
    String token,
    int id, {
    int intervalDays = 180,
  }) => _api.post(
    '/mobile/admin/sanitizations/$id/complete',
    token: token,
    body: {'next_interval_days': intervalDays},
  );
  Future<Map<String, dynamic>> cancelSanitization(String token, int id) =>
      _api.post('/mobile/admin/sanitizations/$id/cancel', token: token);
  Future<Map<String, dynamic>> saveDriver(
    String token,
    int? id,
    Map<String, dynamic> body,
  ) => _api.post(
    id == null ? '/mobile/admin/drivers' : '/mobile/admin/drivers/$id',
    token: token,
    body: body,
  );
  Future<Map<String, dynamic>> deleteDriver(String token, int id) =>
      _api.delete('/mobile/admin/drivers/$id', token: token);
  Future<Map<String, dynamic>> saveRegion(
    String token,
    int? id,
    Map<String, dynamic> body,
  ) => _api.post(
    id == null ? '/mobile/admin/regions' : '/mobile/admin/regions/$id',
    token: token,
    body: body,
  );
  Future<Map<String, dynamic>> deleteRegion(String token, int id) =>
      _api.delete('/mobile/admin/regions/$id', token: token);
  Future<List<Map<String, dynamic>>> routes(String token) async =>
      _items(await _api.get('/mobile/admin/routes', token: token));
  Future<Map<String, dynamic>> route(String token, int id) =>
      _api.get('/mobile/admin/routes/$id', token: token);
  Future<Map<String, dynamic>> routeOptions(String token) =>
      _api.get('/mobile/admin/route-options', token: token);
  Future<Map<String, dynamic>> saveRoute(
    String token,
    int? id,
    Map<String, dynamic> body,
  ) => _api.post(
    id == null ? '/mobile/admin/routes' : '/mobile/admin/routes/$id',
    token: token,
    body: body,
  );
  Future<List<Map<String, dynamic>>> optimizeRoute(
    String token,
    List<Map<String, dynamic>> stops,
  ) async => _items(
    await _api.post(
      '/mobile/admin/routes/optimize',
      token: token,
      body: {'stops': stops},
    ),
    key: 'stops',
  );
  Future<Map<String, dynamic>> deleteRoute(String token, int id) =>
      _api.delete('/mobile/admin/routes/$id', token: token);
  Future<List<Map<String, dynamic>>> clients(String token) async =>
      _items(await _api.get('/mobile/admin/clients', token: token));
  Future<Map<String, dynamic>> client(String token, int id) =>
      _api.get('/mobile/admin/clients/$id', token: token);
  Future<Map<String, dynamic>> clientStats(
    String token,
    int id, {
    String range = 'last_12_months',
    int? locationId,
  }) => _api.get(
    '/mobile/admin/clients/$id/stats?range=$range'
    '${locationId == null ? '' : '&location=$locationId'}',
    token: token,
  );
  Future<Map<String, dynamic>> clientOptions(String token) =>
      _api.get('/mobile/admin/client-options', token: token);
  Future<Map<String, dynamic>> gus(String token, String nip) =>
      _api.post('/mobile/admin/clients/gus', token: token, body: {'nip': nip});
  Future<Map<String, dynamic>> createClient(
    String token,
    Map<String, dynamic> body,
  ) => _api.post('/mobile/admin/clients', token: token, body: body);
  Future<Map<String, dynamic>> updateClient(
    String token,
    int id,
    Map<String, dynamic> body,
  ) => _api.post('/mobile/admin/clients/$id', token: token, body: body);
  Future<Map<String, dynamic>> addClientToRoute(
    String token,
    int clientId,
    int routeId,
  ) => _api.post(
    '/mobile/admin/clients/$clientId/route',
    token: token,
    body: {'delivery_route_id': routeId},
  );
  Future<List<Map<String, dynamic>>> documents(
    String token, {
    int page = 1,
  }) async => _items(
    await _api.get(
      '/mobile/admin/documents?page=$page&per_page=30',
      token: token,
    ),
  );
  Future<Map<String, dynamic>> createFinalInvoice(String token, int id) =>
      _api.post('/mobile/admin/documents/$id/final-invoice', token: token);
  Future<Map<String, dynamic>> deleteDocument(String token, int id) =>
      _api.delete('/mobile/admin/documents/$id', token: token);
  Future<ApiDownload> documentPdf(String token, int id) =>
      _api.download('/mobile/admin/documents/$id/fakturownia', token: token);
  Future<ApiDownload> externalDocumentPdf(String token, int id) =>
      _api.download(
        '/mobile/admin/external-documents/$id/fakturownia',
        token: token,
      );
  Future<Map<String, dynamic>> sendInvoiceToKsef(String token, int id) =>
      _api.post('/mobile/admin/external-documents/$id/ksef', token: token);
  Future<List<Map<String, dynamic>>> products(String token) async =>
      _items(await _api.get('/mobile/admin/products', token: token));
  Future<Map<String, dynamic>> product(String token, int id) =>
      _api.get('/mobile/admin/products/$id', token: token);
  Future<Map<String, dynamic>> createProduct(
    String token,
    Map<String, dynamic> body,
  ) => _api.post('/mobile/admin/products', token: token, body: body);
  Future<Map<String, dynamic>> updateProduct(
    String token,
    int id,
    Map<String, dynamic> body,
  ) => _api.post('/mobile/admin/products/$id', token: token, body: body);
  Future<Map<String, dynamic>> deleteProduct(String token, int id) =>
      _api.delete('/mobile/admin/products/$id', token: token);

  static List<Map<String, dynamic>> _items(
    Map<String, dynamic> response, {
    String key = 'items',
  }) => response[key] is List
      ? (response[key] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
      : const [];
}
