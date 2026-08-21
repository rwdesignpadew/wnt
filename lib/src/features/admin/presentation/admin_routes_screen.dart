import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_route_edit_screen.dart';

class AdminRoutesScreen extends ConsumerStatefulWidget {
  const AdminRoutesScreen({super.key});
  @override
  ConsumerState<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends ConsumerState<AdminRoutesScreen> {
  bool _archived = false;

  @override
  Widget build(BuildContext context) => ref
      .watch(adminRoutesProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminRoutesProvider),
        ),
        data: (allItems) {
          final items =
              allItems
                  .where((item) => (item['is_archived'] == true) == _archived)
                  .toList()
                ..sort((a, b) {
                  final byDate = _archived
                      ? _int(b['sort_at']).compareTo(_int(a['sort_at']))
                      : _int(a['sort_at']).compareTo(_int(b['sort_at']));
                  return byDate != 0
                      ? byDate
                      : _int(b['id']).compareTo(_int(a['id']));
                });
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(adminRoutesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trasy',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminRouteEditScreen(),
                              ),
                            );
                            ref.invalidate(adminRoutesProvider);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Nowa trasa'),
                        ),
                      ],
                    ),
                  );
                }
                if (index == 1) {
                  return SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Bieżące')),
                      ButtonSegment(value: true, label: Text('Archiwalne')),
                    ],
                    selected: {_archived},
                    onSelectionChanged: (value) =>
                        setState(() => _archived = value.first),
                  );
                }
                final route = items[index - 2];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.route_outlined,
                      color: WntColors.brand,
                    ),
                    title: Text(route['title']?.toString() ?? 'Trasa'),
                    subtitle: Text(
                      '${route['subtitle'] ?? ''}\n${route['meta'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Usuń trasę',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteRoute(context, ref, route),
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminRouteDetailScreen(id: _int(route['id'])),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      );
}

Future<void> _deleteRoute(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> route,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Usunąć trasę?'),
      content: Text('Trasa „${route['title'] ?? ''}” zostanie usunięta.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Anuluj'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Usuń'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final token = ref.read(authControllerProvider).session!.token;
    await ref
        .read(adminRepositoryProvider)
        .deleteRoute(token, _int(route['id']));
    ref.invalidate(adminRoutesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trasa została usunięta.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class AdminRouteDetailScreen extends ConsumerStatefulWidget {
  const AdminRouteDetailScreen({required this.id, super.key});
  final int id;
  @override
  ConsumerState<AdminRouteDetailScreen> createState() =>
      _AdminRouteDetailScreenState();
}

class _AdminRouteDetailScreenState
    extends ConsumerState<AdminRouteDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final session = ref.read(authControllerProvider).session!;
    _future = ref.read(adminRepositoryProvider).route(session.token, widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Podgląd trasy')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminRouteEditScreen(id: widget.id),
          ),
        );
        if (mounted) setState(_load);
      },
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edytuj'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AsyncErrorView(
            error: snapshot.error!,
            onRetry: () => setState(_load),
          );
        }
        final route = _map(snapshot.data?['route']) ?? const {};
        final stops = _list(route['stops']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              route['name']?.toString() ?? 'Trasa',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${route['scheduled_date'] ?? ''} · ${route['driver'] ?? 'bez kierowcy'}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < stops.length; index++) ...[
                    ListTile(
                      leading: CircleAvatar(
                        child: Text('${stops[index]['sequence']}'),
                      ),
                      title: Text(
                        '${stops[index]['client_name']} - ${stops[index]['location_name']}',
                      ),
                      subtitle: Text(stops[index]['address']?.toString() ?? ''),
                      trailing: Text(_status(stops[index]['document_status'])),
                    ),
                    if (index < stops.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _status(dynamic status) => switch ('$status') {
  'completed' => 'Obsłużony',
  'missed_closed' => 'Nie zastano',
  _ => 'Do obsługi',
};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];
Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : null;
int _int(dynamic value) => int.tryParse('$value') ?? 0;
