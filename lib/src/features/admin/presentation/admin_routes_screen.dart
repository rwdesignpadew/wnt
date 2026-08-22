import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../driver/application/driver_providers.dart';
import '../../driver/presentation/driver_service_screen.dart';
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

  Future<void> _serviceStop(Map<String, dynamic> stop) async {
    final documentId = _int(stop['document_id']);
    if (documentId < 1) return;
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(driverRepositoryProvider)
          .serviceDocument(token, documentId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverServiceScreen(
            document: _map(response['document']) ?? const {},
            products: _list(response['products']),
          ),
        ),
      );
      if (mounted) setState(_load);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
      );
    }
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
        final mappedStops = stops
            .where(
              (stop) =>
                  double.tryParse('${stop['latitude'] ?? ''}') != null &&
                  double.tryParse('${stop['longitude'] ?? ''}') != null,
            )
            .toList();
        final roadPath = _list(route['road_path']);
        final routeBase = _map(route['base']);
        final completedCount = stops
            .where((stop) => stop['document_status'] == 'completed')
            .length;
        final missedCount = stops
            .where((stop) => stop['document_status'] == 'missed_closed')
            .length;
        final pendingCount = stops.length - completedCount - missedCount;
        final mapHeight = (MediaQuery.sizeOf(context).width * 0.72).clamp(
          300.0,
          520.0,
        );
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RouteStat(
                    label: 'Wszystkie',
                    value: stops.length,
                    color: WntColors.brand,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RouteStat(
                    label: 'Obsłużone',
                    value: completedCount,
                    color: WntColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RouteStat(
                    label: 'Pozostałe',
                    value: pendingCount,
                    color: Colors.orange.shade700,
                  ),
                ),
                if (missedCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RouteStat(
                      label: 'Nie zastano',
                      value: missedCount,
                      color: WntColors.error,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (mappedStops.isNotEmpty) ...[
              SizedBox(
                height: mapHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _AdminRouteMap(
                    stops: mappedStops,
                    roadPath: roadPath,
                    base: routeBase,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Punkty trasy', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final stop in stops) ...[
              _RouteStopCard(stop: stop, onService: () => _serviceStop(stop)),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    ),
  );
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

class _RouteStopCard extends StatelessWidget {
  const _RouteStopCard({required this.stop, required this.onService});

  final Map<String, dynamic> stop;
  final VoidCallback onService;

  @override
  Widget build(BuildContext context) {
    final status = stop['document_status']?.toString();
    final color = status == 'completed'
        ? WntColors.success
        : status == 'missed_closed'
        ? WntColors.error
        : Colors.orange.shade700;
    final canService = _int(stop['document_id']) > 0;
    final summary = stop['products_summary']?.toString().trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: status == 'completed' ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: Text('${stop['sequence']}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop['client_name']?.toString() ?? 'Klient',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(stop['location_name']?.toString() ?? 'Lokalizacja'),
                    const SizedBox(height: 3),
                    Text(
                      stop['address']?.toString() ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _status(status),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(summary, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (canService) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onService,
                icon: Icon(
                  status == 'completed'
                      ? Icons.edit_note_outlined
                      : Icons.assignment_turned_in_outlined,
                ),
                label: Text(
                  status == 'completed'
                      ? 'Edytuj obsługę klienta'
                      : 'Obsłuż klienta',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminRouteMap extends StatelessWidget {
  const _AdminRouteMap({
    required this.stops,
    required this.roadPath,
    required this.base,
  });

  final List<Map<String, dynamic>> stops;
  final List<Map<String, dynamic>> roadPath;
  final Map<String, dynamic>? base;

  Future<void> _onCreated(GoogleMapViewController controller) async {
    final points = stops
        .map(
          (stop) => LatLng(
            latitude: double.parse('${stop['latitude']}'),
            longitude: double.parse('${stop['longitude']}'),
          ),
        )
        .toList();
    final baseLatitude = double.tryParse('${base?['lat'] ?? ''}');
    final baseLongitude = double.tryParse('${base?['lng'] ?? ''}');
    final basePoint = baseLatitude != null && baseLongitude != null
        ? LatLng(latitude: baseLatitude, longitude: baseLongitude)
        : null;
    await controller.addMarkers([
      if (basePoint != null)
        MarkerOptions(
          position: basePoint,
          infoWindow: InfoWindow(
            title: base?['name']?.toString() ?? 'Baza WNT',
            snippet: base?['address']?.toString(),
          ),
          zIndex: 2,
        ),
      for (var index = 0; index < stops.length; index++)
        MarkerOptions(
          position: points[index],
          infoWindow: InfoWindow(
            title: '${stops[index]['sequence']}. ${stops[index]['client_name']}',
            snippet: stops[index]['address']?.toString(),
          ),
        ),
    ]);
    final routePoints = roadPath
        .where(
          (point) =>
              double.tryParse('${point['latitude'] ?? ''}') != null &&
              double.tryParse('${point['longitude'] ?? ''}') != null,
        )
        .map(
          (point) => LatLng(
            latitude: double.parse('${point['latitude']}'),
            longitude: double.parse('${point['longitude']}'),
          ),
        )
        .toList();
    final boundsPoints = [?basePoint, ...points];
    if (routePoints.length > 1) {
      await controller.addPolylines([
        PolylineOptions(points: routePoints, strokeWidth: 7),
      ]);
    }
    if (boundsPoints.length > 1) {
      await controller.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds.createBoundsFromPoints(boundsPoints),
          padding: 55,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = stops.first;
    return GoogleMapsMapView(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          latitude: double.parse('${first['latitude']}'),
          longitude: double.parse('${first['longitude']}'),
        ),
        zoom: 11,
      ),
      onViewCreated: _onCreated,
    );
  }
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
