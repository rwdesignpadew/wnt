import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/driver_providers.dart';
import 'driver_service_screen.dart';
import 'driver_navigation_screen.dart';
import 'driver_manual_wz_screen.dart';

class DriverRouteScreen extends ConsumerWidget {
  const DriverRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(driverRouteProvider);
    return route.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(driverRouteProvider),
      ),
      data: (data) {
        final documents = _list(data['documents']);
        final products = _list(data['products']);
        final routes = _list(data['routes']);
        final selected = _map(data['selected_route']);
        final statistics = _map(data['statistics']);
        final navigationStops = _routeDestinations(documents);
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(driverRouteProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Trasy na dziś i jutro',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (routes.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _int(selected?['id']),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Wybierz trasę'),
                  items: routes
                      .map(
                        (item) => DropdownMenuItem(
                          value: _int(item['id']),
                          child: Text(
                            '${item['scheduled_date']} — ${item['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    ref.read(selectedDriverRouteIdProvider.notifier).state =
                        value;
                  },
                ),
              ],
              const SizedBox(height: 4),
              Text(
                selected == null
                    ? 'Brak przypisanej trasy'
                    : '${selected['name']} · ${documents.length} punktów',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
              ),
              if (selected != null) ...[
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Obsłużeni klienci: ${_int(statistics?['served_clients'])}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text('${_int(statistics?['route_points'])} pkt'),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: navigationStops.isEmpty
                          ? null
                          : () async {
                              final activeCount = documents
                                  .where((document) => !_isServed(document))
                                  .length;
                              final missing =
                                  activeCount - navigationStops.length;
                              if (missing > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$missing punkt(y) pominięto: brak poprawnych współrzędnych GPS.',
                                    ),
                                    backgroundColor: WntColors.error,
                                  ),
                                );
                              }
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DriverNavigationScreen(
                                    destinations: navigationStops,
                                    title:
                                        selected?['name']?.toString() ??
                                        'Trasa',
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Nawiguj trasę'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DriverManualWzScreen(),
                        ),
                      );
                      ref.invalidate(driverRouteProvider);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ręczne WZ'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (documents.isEmpty)
                const EmptyState(
                  icon: Icons.route_outlined,
                  title: 'Brak punktów na dzisiaj',
                  message:
                      'Po przypisaniu trasy przez administratora pojawi się ona tutaj.',
                )
              else
                for (var index = 0; index < documents.length; index++) ...[
                  _StopCard(
                    index: index + 1,
                    document: documents[index],
                    products: products,
                    isNext:
                        '${data['next_document_id']}' ==
                        '${documents[index]['id']}',
                    isSkipped: documents
                        .skip(index + 1)
                        .any((document) => document['status'] == 'completed'),
                    onRefresh: () => ref.invalidate(driverRouteProvider),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _StopCard extends ConsumerStatefulWidget {
  const _StopCard({
    required this.index,
    required this.document,
    required this.products,
    required this.isNext,
    required this.isSkipped,
    required this.onRefresh,
  });

  final int index;
  final Map<String, dynamic> document;
  final List<Map<String, dynamic>> products;
  final bool isNext;
  final bool isSkipped;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_StopCard> createState() => _StopCardState();
}

class _StopCardState extends ConsumerState<_StopCard> {
  bool _busy = false;

  Future<void> _missed() async {
    setState(() => _busy = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final message = await ref
          .read(driverRepositoryProvider)
          .markMissed(token, _int(widget.document['id']));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      widget.onRefresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _map(widget.document['client']) ?? const {};
    final location = _map(widget.document['location']);
    final status = widget.document['status']?.toString() ?? 'planned';
    final completed = status == 'completed';
    final missed =
        status == 'missed_closed' ||
        (widget.document['notes']?.toString().contains('Nie zastano') ?? false);
    final locationName = location?['name']?.toString();
    final address = location?['address']?.toString().trim().isNotEmpty == true
        ? location!['address'].toString()
        : widget.document['delivery_address']?.toString() ?? '';
    final phone = client['phone']?.toString() ?? '';
    final name = client['name']?.toString() ?? 'Klient';
    final title = locationName?.isNotEmpty == true
        ? '$name - $locationName'
        : name;
    final navigationDestination = _documentDestination(widget.document);
    final background = completed
        ? WntColors.successSoft
        : missed
        ? WntColors.errorSoft
        : widget.isSkipped
        ? WntColors.errorSoft
        : widget.isNext
        ? WntColors.brandSoft
        : Colors.white;
    final border = completed
        ? WntColors.success
        : missed
        ? WntColors.error
        : widget.isSkipped
        ? WntColors.error
        : widget.isNext
        ? WntColors.brand
        : WntColors.line;

    return Card(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (address.isNotEmpty)
                        Text(
                          address,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: WntColors.muted),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        widget.isSkipped && !missed
                            ? 'Pominięty — wymaga obsługi'
                            : _statusLabel(status, missed),
                        style: TextStyle(
                          color: border,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (completed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DriverServiceScreen(
                          document: widget.document,
                          products: widget.products,
                        ),
                      ),
                    );
                    widget.onRefresh();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edytuj WZ'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DriverServiceScreen(
                                    document: widget.document,
                                    products: widget.products,
                                  ),
                                ),
                              );
                              if (!context.mounted) return;
                              widget.onRefresh();
                            },
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Obsłuż klienta'),
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Zadzwoń',
                      onPressed: () => const MethodChannel(
                        'pl.wnt/phone',
                      ).invokeMethod<void>('call', {'phone': phone}),
                      icon: const Icon(Icons.phone_outlined),
                    ),
                  ],
                  if (navigationDestination != null) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Nawiguj do klienta',
                      onPressed: _busy
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DriverNavigationScreen(
                                    destinations: [navigationDestination],
                                    title: navigationDestination.title,
                                  ),
                                ),
                              );
                              if (mounted) widget.onRefresh();
                            },
                      icon: const Icon(Icons.navigation_outlined),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Nie zastano klienta',
                    onPressed: _busy ? null : _missed,
                    icon: const Icon(Icons.person_off_outlined),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<DriverNavigationDestination> _routeDestinations(
  List<Map<String, dynamic>> documents,
) => documents
    .where(
      (document) =>
          !_isServed(document) && document['status'] != 'missed_closed',
    )
    .map((document) {
      final client = _map(document['client']) ?? const <String, dynamic>{};
      final location = _map(document['location']);
      final latitude = double.tryParse(
        '${location?['latitude'] ?? client['latitude'] ?? ''}',
      );
      final longitude = double.tryParse(
        '${location?['longitude'] ?? client['longitude'] ?? ''}',
      );
      if (latitude == null || longitude == null) return null;
      return DriverNavigationDestination(
        latitude: latitude,
        longitude: longitude,
        title: '${client['name'] ?? 'Punkt trasy'}',
      );
    })
    .whereType<DriverNavigationDestination>()
    .toList();

DriverNavigationDestination? _documentDestination(
  Map<String, dynamic> document,
) {
  final client = _map(document['client']) ?? const <String, dynamic>{};
  final location = _map(document['location']);
  final latitude = double.tryParse(
    '${location?['latitude'] ?? client['latitude'] ?? ''}',
  );
  final longitude = double.tryParse(
    '${location?['longitude'] ?? client['longitude'] ?? ''}',
  );
  if (latitude == null || longitude == null) return null;
  final clientName = client['name']?.toString() ?? 'Punkt trasy';
  final locationName = location?['name']?.toString().trim() ?? '';
  return DriverNavigationDestination(
    latitude: latitude,
    longitude: longitude,
    title: locationName.isEmpty ? clientName : '$clientName - $locationName',
  );
}

bool _isServed(Map<String, dynamic> document) =>
    document['status'] == 'completed' ||
    (document['completed_at']?.toString().trim().isNotEmpty ?? false);

String _statusLabel(String status, bool missed) {
  if (missed && status != 'completed') {
    return 'Nie zastano';
  }
  return switch (status) {
    'completed' => 'Obsłużony',
    'planned' => 'Do obsługi',
    'in_progress' => 'W obsłudze',
    _ => 'Do obsługi',
  };
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : const [];
Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : null;
int _int(dynamic value) => int.tryParse('$value') ?? 0;
