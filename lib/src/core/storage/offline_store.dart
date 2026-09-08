import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OfflineStore {
  OfflineStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;

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
    final file = await _file('driver_route_$userId');
    if (!await file.exists()) return null;
    try {
      final value = jsonDecode(await file.readAsString());
      return value is Map ? value.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeRoute(int userId, Map<String, dynamic> route) async {
    final file = await _file('driver_route_$userId');
    await _write(file, route);
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
    final route = await readRoute(userId);
    if (route == null) return;
    final documents = route['documents'];
    if (documents is! List) return;
    for (final value in documents) {
      if (value is Map && '${value['id']}' == '$documentId') {
        value.addAll(changes);
        break;
      }
    }
    route['_offline'] = true;
    route['_pending_operations'] = (await readQueue(userId)).length;
    await writeRoute(userId, route);
  }

  Future<List<Map<String, dynamic>>> readQueue(int userId) async {
    final file = await _file('driver_queue_$userId');
    if (!await file.exists()) return [];
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! List) return [];
      return value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeQueue(int userId, List<Map<String, dynamic>> queue) async {
    final file = await _file('driver_queue_$userId');
    await _write(file, queue);
  }

  Future<void> enqueue(int userId, Map<String, dynamic> operation) async {
    final queue = await readQueue(userId);
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
    await writeQueue(userId, queue);
  }

  Future<void> retryBlocked(int userId) async {
    final queue = await readQueue(userId);
    for (final operation in queue) {
      operation.remove('blocked');
      operation.remove('last_error');
      operation.remove('last_attempt_at');
    }
    await writeQueue(userId, queue);
  }

  Future<void> _write(File file, Object value) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
