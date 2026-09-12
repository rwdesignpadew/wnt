import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/offline_store.dart';

class DriverRepository {
  const DriverRepository(this._api, this._offlineStore);

  final ApiClient _api;
  final OfflineStore _offlineStore;
  static final Random _secureRandom = Random.secure();

  Future<Map<String, dynamic>> route(
    String token, {
    required int userId,
    String? date,
    int? routeId,
  }) async {
    await synchronize(token, userId);
    final pending = await _offlineStore.readQueue(userId);
    final blocked = pending.where((item) => item['blocked'] == true).length;
    try {
      final response = await _api.get(
        '/mobile/driver/route',
        token: token,
        query: {'date': ?date, 'route_id': ?routeId?.toString()},
      );
      final cached = <String, dynamic>{
        ...response,
        '_offline': false,
        '_cached_at': DateTime.now().toUtc().toIso8601String(),
        '_pending_operations': pending.length,
        if (blocked > 0)
          '_sync_error':
              '$blocked operacji wymaga ponowienia lub poprawienia danych.',
      };
      await _offlineStore.writeRoute(userId, cached);
      return cached;
    } on ApiException catch (error) {
      if (error.statusCode != null) rethrow;
      final cached = await _offlineStore.readRoute(userId);
      if (cached == null) rethrow;
      return {
        ...cached,
        '_offline': true,
        '_pending_operations': pending.length,
        if (blocked > 0)
          '_sync_error':
              '$blocked operacji wymaga ponowienia lub poprawienia danych.',
      };
    }
  }

  Future<String> markMissed(
    String token,
    int documentId, {
    required int userId,
  }) async {
    final operationId = _newOperationId(userId, documentId, 'missed');
    final body = {'client_operation_id': operationId};
    try {
      final response = await _api.post(
        '/mobile/driver/documents/$documentId/missed',
        token: token,
        body: body,
      );
      return response['message']?.toString() ?? 'Punkt został pominięty.';
    } on ApiException catch (error) {
      final operationStatus = error.payload['operation_status']?.toString();
      final canRetry =
          error.statusCode == null ||
          (error.statusCode ?? 0) >= 500 ||
          operationStatus == 'processing' ||
          operationStatus == 'uncertain';
      if (!canRetry) rethrow;
      await _enqueue(
        userId: userId,
        operationId: operationId,
        path: '/mobile/driver/documents/$documentId/missed',
        body: body,
        documentId: documentId,
        kind: 'missed',
      );
      await _offlineStore.updateDocument(userId, documentId, {
        'status': 'missed_closed',
        'offline_sync_status': 'pending',
      });
      return 'Pominięcie zapisane offline.';
    }
  }

  Future<void> startRoute(
    String token,
    int routeId, {
    required int userId,
  }) async {
    final operationId = _newOperationId(userId, routeId, 'start-route');
    final body = {'client_operation_id': operationId};
    try {
      await _api.post(
        '/mobile/driver/routes/$routeId/start',
        token: token,
        body: body,
      );
    } on ApiException catch (error) {
      if (error.statusCode != null) rethrow;
      await _enqueue(
        userId: userId,
        operationId: operationId,
        path: '/mobile/driver/routes/$routeId/start',
        body: body,
        kind: 'start-route',
      );
    }
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
    required int userId,
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
    bool sanitizationSelected = false,
    int? sanitizationId,
    int? sanitizationCompletedDispenserCount,
    int? sanitizationNextIntervalDays,
    String? sanitizationResultNotes,
  }) async {
    final operationId = _newOperationId(userId, documentId, 'complete');
    final body = <String, dynamic>{
      'client_operation_id': operationId,
      'quantities': quantities.map((id, quantity) => MapEntry('$id', quantity)),
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
      'sanitization_selected': sanitizationSelected,
      'sanitization_id': ?sanitizationId,
      'sanitization_completed_dispenser_count':
          ?sanitizationCompletedDispenserCount,
      'sanitization_next_interval_days': ?sanitizationNextIntervalDays,
      'sanitization_result_notes': ?sanitizationResultNotes,
    };
    try {
      final response = await _api.post(
        '/mobile/driver/documents/$documentId/complete',
        token: token,
        body: body,
      );
      if (_completionConfirmed(response)) return response;

      await _enqueue(
        userId: userId,
        operationId: operationId,
        path: '/mobile/driver/documents/$documentId/complete',
        body: body,
        documentId: documentId,
        kind: 'complete',
      );
      await _offlineStore.markDocumentPending(userId, documentId);
      return {
        ...response,
        'queued_for_sync': true,
        'message':
            'WZ zapisany bezpiecznie. Oczekuje na potwierdzenie numeru i dokumentów w Fakturowni.',
      };
    } on ApiException catch (error) {
      final operationStatus = error.payload['operation_status']?.toString();
      final canRetry =
          error.statusCode == null ||
          (error.statusCode ?? 0) >= 500 ||
          operationStatus == 'processing' ||
          operationStatus == 'uncertain';
      if (!canRetry) rethrow;
      await _enqueue(
        userId: userId,
        operationId: operationId,
        path: '/mobile/driver/documents/$documentId/complete',
        body: body,
        documentId: documentId,
        kind: 'complete',
      );
      await _offlineStore.markDocumentPending(userId, documentId);
      return {
        'queued_offline': true,
        'message':
            'Obsługa zapisana offline. Dokumenty zostaną utworzone po synchronizacji.',
      };
    }
  }

  Future<ApiDownload> completionPreview({
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
    bool sanitizationSelected = false,
    int? sanitizationId,
    int? sanitizationCompletedDispenserCount,
    int? sanitizationNextIntervalDays,
    String? sanitizationResultNotes,
    String type = 'wz',
  }) => _api.download(
    '/mobile/driver/documents/$documentId/completion-preview?type=$type',
    token: token,
    body: {
      'quantities': quantities.map((id, quantity) => MapEntry('$id', quantity)),
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
      'sanitization_selected': sanitizationSelected,
      'sanitization_id': ?sanitizationId,
      'sanitization_completed_dispenser_count':
          ?sanitizationCompletedDispenserCount,
      'sanitization_next_interval_days': ?sanitizationNextIntervalDays,
      'sanitization_result_notes': ?sanitizationResultNotes,
    },
  );

  Future<int> pendingCount(int userId) async =>
      (await _offlineStore.readQueue(userId)).length;

  Future<int> synchronize(String token, int userId) async {
    final queue = await _offlineStore.readQueue(userId);
    if (queue.isEmpty) return 0;
    var synchronized = 0;
    for (final operation in queue) {
      if (operation['blocked'] == true) {
        continue;
      }
      final operationId = operation['operation_id']?.toString() ?? '';
      if (operationId.isEmpty) continue;
      try {
        final response = await _api.send(
          operation['method']?.toString() ?? 'POST',
          operation['path']?.toString() ?? '',
          token: token,
          body: (operation['body'] as Map?)?.cast<String, dynamic>(),
        );
        if (operation['kind']?.toString() == 'complete') {
          final documentId = int.tryParse('${operation['document_id']}') ?? 0;
          final confirmed = await _confirmCompletedDocument(
            token,
            documentId,
            response,
          );
          if (!confirmed) {
            await _offlineStore.updateOperation(userId, operationId, {
              'attempts': (int.tryParse('${operation['attempts']}') ?? 0) + 1,
              'awaiting_confirmation': true,
              'last_error':
                  'Serwer zapisał obsługę, ale WZ/PZ nie są jeszcze potwierdzone w Fakturowni.',
              'last_attempt_at': DateTime.now().toUtc().toIso8601String(),
            });
            continue;
          }
        }
        await _offlineStore.removeOperation(userId, operationId);
        synchronized++;
      } on ApiException catch (error) {
        final operationStatus = error.payload['operation_status']?.toString();
        if (operation['kind']?.toString() == 'complete' &&
            operationStatus == 'uncertain') {
          final recovery = await _recoverUncertainCompletion(
            token,
            userId,
            operation,
          );
          if (recovery == 1) {
            await _offlineStore.removeOperation(userId, operationId);
            synchronized++;
            continue;
          }
          if (recovery == 2) continue;
        }
        final canRetry =
            error.statusCode == null ||
            (error.statusCode ?? 0) >= 500 ||
            operationStatus == 'processing' ||
            operationStatus == 'uncertain';
        await _offlineStore.updateOperation(userId, operationId, {
          'attempts': (int.tryParse('${operation['attempts']}') ?? 0) + 1,
          'last_error': error.message,
          'last_attempt_at': DateTime.now().toUtc().toIso8601String(),
          if (!canRetry) 'blocked': true,
        });
        if (error.statusCode == null) {
          break;
        }
      }
    }
    return synchronized;
  }

  Future<bool> _confirmCompletedDocument(
    String token,
    int documentId,
    Map<String, dynamic> response,
  ) async {
    if (_completionConfirmed(response)) return true;
    if (documentId < 1) return false;

    final synchronized = await _api.post(
      '/mobile/driver/documents/$documentId/warehouse-sync',
      token: token,
    );
    return _completionConfirmed(synchronized);
  }

  bool _completionConfirmed(Map<String, dynamic> response) {
    final rawDocument = response['document'];
    if (rawDocument is! Map) return false;
    final document = rawDocument.cast<String, dynamic>();
    if (document['status']?.toString() != 'completed') return false;
    if (document['warehouse_sync_required'] is! bool ||
        document['warehouse_sync_complete'] is! bool) {
      return false;
    }
    return document['warehouse_sync_required'] != true ||
        document['warehouse_sync_complete'] == true;
  }

  Future<int> _recoverUncertainCompletion(
    String token,
    int userId,
    Map<String, dynamic> operation,
  ) async {
    final documentId = int.tryParse('${operation['document_id']}') ?? 0;
    if (documentId < 1) return 0;

    try {
      final current = await serviceDocument(token, documentId);
      final rawDocument = current['document'];
      if (rawDocument is! Map) return 0;
      if (rawDocument['status']?.toString() == 'completed') {
        return await _confirmCompletedDocument(token, documentId, current)
            ? 1
            : 0;
      }
      if (rawDocument['status']?.toString() != 'planned') return 0;

      // The business write is one database transaction. If an uncertain
      // idempotency record exists but the document is still planned, that
      // transaction did not commit and the exact payload can safely receive a
      // new operation identity for the next attempt.
      final oldOperationId = operation['operation_id']?.toString() ?? '';
      final newOperationId = _newOperationId(
        userId,
        documentId,
        'complete-retry',
      );
      final body = (operation['body'] as Map?)?.cast<String, dynamic>() ?? {};
      await _offlineStore.updateOperation(userId, oldOperationId, {
        'operation_id': newOperationId,
        'body': {...body, 'client_operation_id': newOperationId},
        'attempts': 0,
        'blocked': false,
        'awaiting_confirmation': false,
        'last_error': null,
        'last_attempt_at': null,
      });
      return 2;
    } on ApiException {
      return 0;
    }
  }

  Future<void> retryBlocked(int userId) => _offlineStore.retryBlocked(userId);

  String _newOperationId(int userId, int resourceId, String kind) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final nonce = List.generate(
      12,
      (_) => _secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    return '$userId-$resourceId-$kind-$timestamp-$nonce';
  }

  Future<Map<String, dynamic>> completeSanitization({
    required String token,
    required int userId,
    required int documentId,
    required int sanitizationId,
    required int completedDispenserCount,
    int intervalDays = 180,
    String? resultNotes,
  }) async {
    final operationId = _newOperationId(userId, sanitizationId, 'sanitization');
    final path =
        '/mobile/driver/documents/$documentId/sanitizations/$sanitizationId/complete';
    final body = <String, dynamic>{
      'client_operation_id': operationId,
      'completed_dispenser_count': completedDispenserCount,
      'next_interval_days': intervalDays,
      'result_notes': resultNotes,
    };
    try {
      return await _api.post(path, token: token, body: body);
    } on ApiException catch (error) {
      if (error.statusCode != null) rethrow;
      await _enqueue(
        userId: userId,
        operationId: operationId,
        path: path,
        body: body,
        documentId: documentId,
        kind: 'sanitization',
      );
      return {
        'queued_offline': true,
        'message': 'Sanityzacja zapisana offline.',
      };
    }
  }

  Future<void> _enqueue({
    required int userId,
    required String operationId,
    required String path,
    required Map<String, dynamic> body,
    int? documentId,
    required String kind,
  }) => _offlineStore.enqueue(userId, {
    'operation_id': operationId,
    'method': 'POST',
    'path': path,
    'body': body,
    'document_id': ?documentId,
    'kind': kind,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'attempts': 0,
  });

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

  Future<ApiDownload> documentPreview(String token, int documentId) =>
      _api.download(
        '/mobile/driver/documents/$documentId/preview?type=pz',
        token: token,
      );

  Future<String> emailDocument(String token, int documentId) async {
    final response = await _api.post(
      '/mobile/driver/documents/$documentId/email',
      token: token,
    );
    return response['message']?.toString() ?? 'WZ wysłany do klienta.';
  }
}
