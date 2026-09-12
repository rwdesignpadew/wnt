import 'dart:convert';
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

  test(
    'damaged primary queue is recovered from the last complete backup',
    () async {
      await store.writeQueue(7, [
        {'operation_id': 'operation-1'},
      ]);
      await store.writeQueue(7, [
        {'operation_id': 'operation-1'},
        {'operation_id': 'operation-2'},
      ]);

      final queueFile = File(
        '${directory.path}${Platform.pathSeparator}offline'
        '${Platform.pathSeparator}driver_queue_7.json',
      );
      await queueFile.writeAsString('{przerwany zapis');

      final reopened = OfflineStore(supportDirectory: () async => directory);
      final recovered = await reopened.readQueue(7);

      expect(recovered.map((item) => item['operation_id']), ['operation-1']);
    },
  );

  test(
    'a complete temporary queue wins after an interrupted atomic replace',
    () async {
      await store.writeQueue(7, [
        {'operation_id': 'operation-1'},
      ]);
      final queueFile = File(
        '${directory.path}${Platform.pathSeparator}offline'
        '${Platform.pathSeparator}driver_queue_7.json',
      );
      await File('${queueFile.path}.tmp').writeAsString(
        jsonEncode([
          {'operation_id': 'operation-1'},
          {'operation_id': 'operation-2'},
        ]),
      );

      final reopened = OfflineStore(supportDirectory: () async => directory);
      final recovered = await reopened.readQueue(7);

      expect(recovered.map((item) => item['operation_id']), [
        'operation-1',
        'operation-2',
      ]);
    },
  );

  test(
    'removing an acknowledged operation never drops a concurrent enqueue',
    () async {
      await store.enqueue(7, {'operation_id': 'operation-1'});

      await Future.wait([
        store.removeOperation(7, 'operation-1'),
        store.enqueue(7, {'operation_id': 'operation-2'}),
      ]);

      final queue = await store.readQueue(7);
      expect(queue.map((item) => item['operation_id']), ['operation-2']);
    },
  );
}
