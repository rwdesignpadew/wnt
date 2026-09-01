import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/application/home_navigation_provider.dart';
import '../application/admin_providers.dart';

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  Future<void> _markAllRead(WidgetRef ref) async {
    final token = ref.read(authControllerProvider).session!.token;
    await ref.read(adminRepositoryProvider).markAllNotificationsRead(token);
    ref.invalidate(adminNotificationsProvider);
  }

  Future<void> _markRead(WidgetRef ref, int id) async {
    final token = ref.read(authControllerProvider).session!.token;
    await ref.read(adminRepositoryProvider).markNotificationRead(token, id);
    ref.invalidate(adminNotificationsProvider);
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) async {
    if (item['is_read'] != true) {
      await _markRead(ref, _int(item['id']));
      if (!context.mounted) return;
    }

    final data = item['data'] is Map
        ? (item['data'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final screen = '${data['screen'] ?? ''}'.toLowerCase();
    final type = '${item['type'] ?? data['type'] ?? ''}'.toLowerCase();

    final destination = switch (screen) {
      'routes' || 'driver_route' => 1,
      'orders' || 'client_orders' => 2,
      'documents' => 3,
      'clients' || 'client_service' => 4,
      _ when type.startsWith('route.') => 1,
      _ when type.startsWith('order.') => 2,
      _ when type.contains('document') || type.contains('equipment') => 3,
      _ => 4,
    };

    ref.read(homeNavigationIndexProvider.notifier).state = destination;
    ref.invalidate(adminNotificationsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminNotificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Powiadomienia'),
        actions: [
          TextButton(
            onPressed: state.valueOrNull?['unread_count'] == 0
                ? null
                : () => _markAllRead(ref),
            child: const Text('Przeczytaj wszystkie'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          final items = (data['items'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList();
          if (items.isEmpty) {
            return const Center(child: Text('Brak powiadomień.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminNotificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final read = item['is_read'] == true;
                return Card(
                  color: read ? null : WntColors.brandSoft,
                  child: ListTile(
                    leading: Icon(
                      read
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined,
                      color: read ? WntColors.muted : WntColors.brand,
                    ),
                    title: Text(
                      '${item['title'] ?? 'Powiadomienie'}',
                      style: TextStyle(
                        fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${item['body'] ?? ''}\n${_notificationDate(item['created_at'])}',
                    ),
                    isThreeLine: true,
                    onTap: () => _openNotification(context, ref, item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

int _int(dynamic value) => int.tryParse('$value') ?? 0;

String _notificationDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}, ${two(date.hour)}:${two(date.minute)}';
}
