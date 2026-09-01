import '../../../core/network/api_client.dart';

class DriverRepository {
  const DriverRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> route(
    String token, {
    String? date,
    int? routeId,
  }) {
    return _api.get(
      '/mobile/driver/route',
      token: token,
      query: {'date': ?date, 'route_id': ?routeId?.toString()},
    );
  }

  Future<String> markMissed(String token, int documentId) async {
    final response = await _api.post(
      '/mobile/driver/documents/$documentId/missed',
      token: token,
    );
    return response['message']?.toString() ?? 'Punkt został pominięty.';
  }

  Future<void> startRoute(String token, int routeId) async {
    await _api.post('/mobile/driver/routes/$routeId/start', token: token);
  }

  Future<Map<String, dynamic>> manualOptions(String token) =>
      _api.get('/mobile/driver/manual-options', token: token);

  Future<Map<String, dynamic>> createManualDocument(
    String token,
    int clientId,
    int? locationId,
  ) => _api.post(
    '/mobile/driver/manual-documents',
    token: token,
    body: {'client_id': clientId, 'client_location_id': locationId},
  );

  Future<void> discardManualDocument(String token, int documentId) async {
    await _api.delete(
      '/mobile/driver/manual-documents/$documentId',
      token: token,
    );
  }

  Future<void> sendLocation(
    String token, {
    required double latitude,
    required double longitude,
    double? accuracy,
    double? heading,
    double? speed,
  }) async {
    await _api.post(
      '/mobile/driver/location',
      token: token,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'heading': heading,
        'speed': speed,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> complete({
    required String token,
    required int documentId,
    required Map<int, int> quantities,
    Map<int, int> packageQuantities = const {},
    required String paymentMethod,
    required String signatureData,
    required String signedBy,
    String? notes,
    double? cashCollected,
    bool customerRequestsInvoice = false,
    bool correction = false,
    List<Map<String, dynamic>> rentalReturns = const [],
  }) {
    return _api.post(
      '/mobile/driver/documents/$documentId/complete',
      token: token,
      body: {
        'quantities': quantities.map(
          (id, quantity) => MapEntry('$id', quantity),
        ),
        'package_quantities': packageQuantities.map(
          (id, quantity) => MapEntry('$id', quantity),
        ),
        'payment_method': paymentMethod,
        'signature_data': signatureData,
        'signed_by': signedBy,
        'notes': notes,
        'cash_collected': cashCollected,
        'customer_requests_invoice': customerRequestsInvoice,
        'correction': correction,
        'rental_returns': rentalReturns,
      },
    );
  }

  Future<Map<String, dynamic>> completeSanitization({
    required String token,
    required int documentId,
    required int sanitizationId,
    required int completedDispenserCount,
    int intervalDays = 180,
    String? resultNotes,
  }) => _api.post(
    '/mobile/driver/documents/$documentId/sanitizations/$sanitizationId/complete',
    token: token,
    body: {
      'completed_dispenser_count': completedDispenserCount,
      'next_interval_days': intervalDays,
      'result_notes': resultNotes,
    },
  );

  Future<Map<String, dynamic>> serviceDocument(String token, int documentId) =>
      _api.get('/mobile/driver/documents/$documentId', token: token);

  Future<ApiDownload> documentPdf(String token, int documentId) async {
    try {
      return await _api.download(
        '/mobile/driver/documents/$documentId/fakturownia',
        token: token,
      );
    } catch (_) {
      return _api.download(
        '/mobile/driver/documents/$documentId/preview',
        token: token,
      );
    }
  }

  Future<String> emailDocument(String token, int documentId) async {
    final response = await _api.post(
      '/mobile/driver/documents/$documentId/email',
      token: token,
    );
    return response['message']?.toString() ?? 'WZ wysłany do klienta.';
  }
}
