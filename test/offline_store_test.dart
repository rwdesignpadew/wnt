import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woda_na_telefon/src/core/storage/offline_store.dart';

void main() {
  late Directory directory;
  late OfflineStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wnt_offline_test_');
    store = OfflineStore(supportDirectory: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('route cache survives creating a new store instance', () async {
    await store.writeRoute(7, {
      'documents': [
        {'id': 41, 'status': 'planned'},
      ],
    });

    final reopened = OfflineStore(supportDirectory: () async => directory);
    final route = await reopened.readRoute(7);

    expect(route?['documents'], hasLength(1));
    expect((route?['documents'] as List).first['id'], 41);
  });

  test('queue is persistent, ordered and deduplicated', () async {
    final first = {'operation_id': 'operation-1', 'path': '/first'};
    await store.enqueue(7, first);
    await store.enqueue(7, first);
    await store.enqueue(7, {'operation_id': 'operation-2', 'path': '/second'});

    final reopened = OfflineStore(supportDirectory: () async => directory);
    final queue = await reopened.readQueue(7);

    expect(queue.map((item) => item['operation_id']), [
      'operation-1',
      'operation-2',
    ]);
  });

  test('offline completion marks the cached route point as pending', () async {
    await store.writeRoute(7, {
      'documents': [
        {'id': 41, 'status': 'planned'},
      ],
    });
    await store.enqueue(7, {'operation_id': 'operation-1', 'document_id': 41});

    await store.markDocumentPending(7, 41);

    final route = await store.readRoute(7);
    final document = (route?['documents'] as List).first as Map;
    expect(document['status'], 'completed');
    expect(document['offline_sync_status'], 'pending');
    expect(route?['_pending_operations'], 1);
  });

  test('manual retry unblocks rejected operations', () async {
    await store.writeQueue(7, [
      {
        'operation_id': 'operation-1',
        'blocked': true,
        'last_error': 'Nieprawidlowe dane',
      },
    ]);

    await store.retryBlocked(7);

    final operation = (await store.readQueue(7)).single;
    expect(operation.containsKey('blocked'), isFalse);
    expect(operation.containsKey('last_error'), isFalse);
  });
}
