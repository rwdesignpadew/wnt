import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OfflineStore {
  OfflineStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;
  static final Map<String, Completer<void>> _locks = {};

  Future<File> _file(String name) async {
    final directory = await _supportDirectory();
    final offlineDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}offline',
    );
    if (!await offlineDirectory.exists()) {
      await offlineDirectory.create(recursive: true);
    }
    return File('${offlineDirectory.path}${Platform.pathSeparator}$name.json');
  }

  Future<Map<String, dynamic>?> readRoute(int userId) async {
    return _withLock('route-$userId', () async {
      final file = await _file('driver_route_$userId');
      final value = await _readJson(file);
      return value is Map ? value.cast<String, dynamic>() : null;
    });
  }

  Future<void> writeRoute(int userId, Map<String, dynamic> route) async {
    await _withLock('route-$userId', () async {
      final file = await _file('driver_route_$userId');
      await _write(file, route);
    });
  }

  Future<void> markDocumentPending(int userId, int documentId) async {
    await updateDocument(userId, documentId, {
      'status': 'completed',
      'offline_sync_status': 'pending',
    });
  }

  Future<void> updateDocument(
    int userId,
    int documentId,
    Map<String, dynamic> changes,
  ) async {
    final pendingCount = (await readQueue(userId)).length;
    await _withLock('route-$userId', () async {
      final file = await _file('driver_route_$userId');
      final raw = await _readJson(file);
      if (raw is! Map) return;
      final route = raw.cast<String, dynamic>();
      final documents = route['documents'];
      if (documents is! List) return;
      for (final value in documents) {
        if (value is Map && '${value['id']}' == '$documentId') {
          value.addAll(changes);
          break;
        }
      }
      route['_offline'] = true;
      route['_pending_operations'] = pendingCount;
      await _write(file, route);
    });
  }

  Future<List<Map<String, dynamic>>> readQueue(int userId) async {
    return _withLock('queue-$userId', () => _readQueueUnlocked(userId));
  }

  Future<void> writeQueue(int userId, List<Map<String, dynamic>> queue) async {
    await _withLock('queue-$userId', () => _writeQueueUnlocked(userId, queue));
  }

  Future<void> enqueue(int userId, Map<String, dynamic> operation) async {
    await _withLock('queue-$userId', () async {
      final queue = await _readQueueUnlocked(userId);
      final operationId = operation['operation_id']?.toString();
      final existingIndex = queue.indexWhere(
        (item) => item['operation_id']?.toString() == operationId,
      );
      if (existingIndex >= 0) {
        queue[existingIndex] = {
          ...operation,
          'created_at': queue[existingIndex]['created_at'],
        };
      } else {
        queue.add(operation);
      }
      await _writeQueueUnlocked(userId, queue);
    });
  }

  Future<void> updateOperation(
    int userId,
    String operationId,
    Map<String, dynamic> changes,
  ) async {
    await _withLock('queue-$userId', () async {
      final queue = await _readQueueUnlocked(userId);
      final index = queue.indexWhere(
        (item) => item['operation_id']?.toString() == operationId,
      );
      if (index < 0) return;
      queue[index] = {...queue[index], ...changes};
      await _writeQueueUnlocked(userId, queue);
    });
  }

  Future<void> removeOperation(int userId, String operationId) async {
    await _withLock('queue-$userId', () async {
      final queue = await _readQueueUnlocked(userId);
      queue.removeWhere(
        (item) => item['operation_id']?.toString() == operationId,
      );
      await _writeQueueUnlocked(userId, queue);
    });
  }

  Future<void> retryBlocked(int userId) async {
    await _withLock('queue-$userId', () async {
      final queue = await _readQueueUnlocked(userId);
      for (final operation in queue) {
        operation.remove('blocked');
        operation.remove('last_error');
        operation.remove('last_attempt_at');
      }
      await _writeQueueUnlocked(userId, queue);
    });
  }

  Future<List<Map<String, dynamic>>> _readQueueUnlocked(int userId) async {
    final file = await _file('driver_queue_$userId');
    final value = await _readJson(file);
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<void> _writeQueueUnlocked(
    int userId,
    List<Map<String, dynamic>> queue,
  ) async {
    final file = await _file('driver_queue_$userId');
    await _write(file, queue);
  }

  Future<dynamic> _readJson(File file) async {
    for (final candidate in [
      File('${file.path}.tmp'),
      file,
      File('${file.path}.bak'),
    ]) {
      if (!await candidate.exists()) continue;
      try {
        return jsonDecode(await candidate.readAsString());
      } catch (_) {
        // A previous complete copy remains available as .bak. Never interpret
        // one damaged write as an intentionally empty offline queue.
      }
    }
    return null;
  }

  Future<void> _write(File file, Object value) async {
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(jsonEncode(value), flush: true);

    if (await file.exists()) {
      var currentIsValid = false;
      try {
        jsonDecode(await file.readAsString());
        currentIsValid = true;
      } catch (_) {
        currentIsValid = false;
      }

      if (currentIsValid) {
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
      } else {
        await file.delete();
      }
    }
    await temporary.rename(file.path);
  }

  Future<T> _withLock<T>(String key, Future<T> Function() action) async {
    while (_locks.containsKey(key)) {
      await _locks[key]!.future;
    }

    final completer = Completer<void>();
    _locks[key] = completer;
    try {
      return await action();
    } finally {
      _locks.remove(key);
      completer.complete();
    }
  }
}
