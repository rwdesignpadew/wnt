import 'dart:async';
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
  late OfflineStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wnt-offline-sync-');
    store = OfflineStore(supportDirectory: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'local completion is removed only after WZ and PZ confirmation',
    () async {
      await store.enqueue(7, _completeOperation());
      final paths = <String>[];
      final repository = DriverRepository(
        ApiClient(
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/warehouse-sync')) {
              return http.Response(
                jsonEncode({
                  'document': {
                    'id': 41,
                    'status': 'completed',
                    'warehouse_sync_required': true,
                    'warehouse_sync_complete': true,
                    'warehouse_wz_confirmed': true,
                    'warehouse_pz_confirmed': true,
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'document': {
                  'id': 41,
                  'status': 'completed',
                  'warehouse_sync_required': true,
                  'warehouse_sync_complete': false,
                },
              }),
              200,
            );
          }),
        ),
        store,
      );

      final synchronized = await repository.synchronize('token', 7);

      expect(synchronized, 1);
      expect(await store.readQueue(7), isEmpty);
      expect(paths, [
        '/api/mobile/driver/documents/41/complete',
        '/api/mobile/driver/documents/41/warehouse-sync',
      ]);
    },
  );

  test(
    'local completion stays queued while warehouse confirmation is pending',
    () async {
      await store.enqueue(7, _completeOperation());
      final repository = DriverRepository(
        ApiClient(
          client: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'document': {
                  'id': 41,
                  'status': 'completed',
                  'warehouse_sync_required': true,
                  'warehouse_sync_complete': false,
                },
              }),
              request.url.path.endsWith('/warehouse-sync') ? 202 : 200,
            );
          }),
        ),
        store,
      );

      final synchronized = await repository.synchronize('token', 7);
      final queue = await store.readQueue(7);

      expect(synchronized, 0);
      expect(queue, hasLength(1));
      expect(queue.single['awaiting_confirmation'], isTrue);
      expect(queue.single['blocked'], isNot(true));
    },
  );

  test('operation added during synchronization is never overwritten', () async {
    await store.enqueue(7, {
      'operation_id': 'operation-1',
      'method': 'POST',
      'path': '/mobile/driver/documents/41/missed',
      'body': {'client_operation_id': 'operation-1'},
      'document_id': 41,
      'kind': 'missed',
      'attempts': 0,
    });
    final requestStarted = Completer<void>();
    final releaseResponse = Completer<void>();
    final repository = DriverRepository(
      ApiClient(
        client: MockClient((request) async {
          requestStarted.complete();
          await releaseResponse.future;
          return http.Response(jsonEncode({'message': 'OK'}), 200);
        }),
      ),
      store,
    );

    final synchronization = repository.synchronize('token', 7);
    await requestStarted.future;
    await store.enqueue(7, {
      'operation_id': 'operation-2',
      'method': 'POST',
      'path': '/mobile/driver/documents/42/missed',
      'body': {'client_operation_id': 'operation-2'},
      'document_id': 42,
      'kind': 'missed',
      'attempts': 0,
    });
    releaseResponse.complete();
    await synchronization;

    final queue = await store.readQueue(7);
    expect(queue.map((item) => item['operation_id']), ['operation-2']);
  });

  test(
    'online completion stays local when Fakturownia is not confirmed',
    () async {
      final repository = DriverRepository(
        ApiClient(
          client: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'document': {
                  'id': 41,
                  'status': 'completed',
                  'warehouse_sync_required': true,
                  'warehouse_sync_complete': false,
                },
              }),
              200,
            ),
          ),
        ),
        store,
      );

      final response = await repository.complete(
        token: 'token',
        userId: 7,
        documentId: 41,
        quantities: const {1: 2},
        paymentMethod: 'transfer',
        signatureData: 'data:image/png;base64,dGVzdA==',
        signedBy: 'Odbiorca',
      );

      expect(response['queued_for_sync'], isTrue);
      expect(await store.readQueue(7), hasLength(1));
    },
  );

  test(
    'server error after submit keeps the completion in the local queue',
    () async {
      final repository = DriverRepository(
        ApiClient(
          client: MockClient(
            (request) async =>
                http.Response(jsonEncode({'message': 'Blad serwera'}), 500),
          ),
        ),
        store,
      );

      final response = await repository.complete(
        token: 'token',
        userId: 7,
        documentId: 41,
        quantities: const {1: 2},
        paymentMethod: 'transfer',
        signatureData: 'data:image/png;base64,dGVzdA==',
        signedBy: 'Odbiorca',
      );

      expect(response['queued_offline'], isTrue);
      expect(await store.readQueue(7), hasLength(1));
    },
  );

  test(
    'uncertain uncommitted completion gets a new safe operation id',
    () async {
      await store.enqueue(7, _completeOperation());
      final repository = DriverRepository(
        ApiClient(
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'document': {
                    'id': 41,
                    'status': 'planned',
                    'warehouse_sync_required': true,
                    'warehouse_sync_complete': false,
                  },
                }),
                200,
              );
            }
            final body = (jsonDecode(request.body) as Map)
                .cast<String, dynamic>();
            if (body['client_operation_id'] == 'operation-complete-1') {
              return http.Response(
                jsonEncode({
                  'message': 'Operacja mogla zostac wykonana.',
                  'operation_status': 'uncertain',
                }),
                409,
              );
            }
            return http.Response(
              jsonEncode({
                'document': {
                  'id': 41,
                  'status': 'completed',
                  'warehouse_sync_required': false,
                  'warehouse_sync_complete': true,
                },
              }),
              200,
            );
          }),
        ),
        store,
      );

      expect(await repository.synchronize('token', 7), 0);
      final rekeyed = (await store.readQueue(7)).single;
      expect(rekeyed['operation_id'], startsWith('7-41-complete-retry-'));
      expect(rekeyed['body']['client_operation_id'], rekeyed['operation_id']);
      expect(rekeyed['blocked'], isFalse);

      expect(await repository.synchronize('token', 7), 1);
      expect(await store.readQueue(7), isEmpty);
    },
  );
}

Map<String, dynamic> _completeOperation() => {
  'operation_id': 'operation-complete-1',
  'method': 'POST',
  'path': '/mobile/driver/documents/41/complete',
  'body': {'client_operation_id': 'operation-complete-1'},
  'document_id': 41,
  'kind': 'complete',
  'attempts': 0,
};
