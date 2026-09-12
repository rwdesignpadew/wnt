import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  String _tab = 'current';

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
          final active = allItems
              .where((item) => item['is_archived'] != true)
              .toList();
          final recurringCount = active
              .where((item) => item['is_recurring'] == true)
              .length;
          final currentCount = active.length - recurringCount;
          final archiveCount = allItems
              .where((item) => item['is_archived'] == true)
              .length;
          final missedCount = _list(
            ref.watch(adminMissedRoutesProvider(null)).valueOrNull?['items'],
          ).length;
          final items =
              allItems
                  .where(
                    (item) => switch (_tab) {
                      'recurring' =>
                        item['is_archived'] != true &&
                            item['is_recurring'] == true,
                      'archive' => item['is_archived'] == true,
                      _ =>
                        item['is_archived'] != true &&
                            item['is_recurring'] != true,
                    },
                  )
                  .toList()
                ..sort((a, b) {
                  final byDate = _tab == 'archive'
                      ? _int(b['sort_at']).compareTo(_int(a['sort_at']))
                      : _int(a['sort_at']).compareTo(_int(b['sort_at']));
                  return byDate != 0
                      ? byDate
                      : _int(b['id']).compareTo(_int(a['id']));
                });
          final header = Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RouteFilters(
                  selected: _tab,
                  tabs: [
                    ('current', 'Bieżące', currentCount),
                    ('recurring', 'Cykliczne', recurringCount),
                    ('missed', 'Pominięci', missedCount),
                    ('archive', 'Archiwum', archiveCount),
                  ],
                  onChanged: (value) => setState(() => _tab = value),
                ),
              ),
            ],
          );
          if (_tab == 'missed') {
            return Column(
              children: [
                header,
                const SizedBox(height: 8),
                const Expanded(child: _MissedRoutesView()),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(adminRoutesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) return header;
                final route = items[index - 1];
                final planned = route['is_planned_occurrence'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: planned ? Colors.orange.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: planned
                            ? Colors.orange.shade300
                            : WntColors.line,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        route['is_recurring'] == true
                            ? Icons.event_repeat_outlined
                            : Icons.route_outlined,
                        color: WntColors.brand,
                      ),
                      title: Text(route['title']?.toString() ?? 'Trasa'),
                      subtitle: Text(
                        '${route['subtitle'] ?? ''}\n'
                        '${route['meta'] ?? ''}'
                        '${route['is_recurring'] == true ? ' · co ${route['recurrence_interval_days']} dni' : ''}',
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
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _AdminRouteMap(
                          stops: mappedStops,
                          roadPath: roadPath,
                          base: routeBase,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          tooltip: 'Mapa na pełnym ekranie',
                          icon: const Icon(Icons.fullscreen),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _AdminRouteFullscreenMap(
                                routeName: route['name']?.toString() ?? 'Trasa',
                                stops: mappedStops,
                                roadPath: roadPath,
                                base: routeBase,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

  Future<ImageDescriptor> _numberedMarker(int sequence) async {
    const size = 104.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final shadow = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    final fill = Paint()..color = WntColors.brand;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(const Offset(54, 54), 39, shadow);
    canvas.drawCircle(const Offset(52, 52), 38, fill);
    canvas.drawCircle(const Offset(52, 52), 38, border);

    final painter = TextPainter(
      text: TextSpan(
        text: '$sequence',
        style: TextStyle(
          color: Colors.white,
          fontSize: sequence > 99 ? 28 : 34,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return ImageDescriptor.defaultImage;
    return registerBitmapImage(bitmap: bytes, width: 52, height: 52);
  }

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
    final numberedIcons = <int, ImageDescriptor>{};
    for (final stop in stops) {
      final sequence = _int(stop['sequence']);
      numberedIcons[sequence] ??= await _numberedMarker(sequence);
    }
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
          icon: numberedIcons[_int(stops[index]['sequence'])]!,
          infoWindow: InfoWindow(
            title:
                '${stops[index]['sequence']}. ${stops[index]['client_name']}',
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
        PolylineOptions(
          points: routePoints,
          strokeColor: WntColors.brand,
          strokeWidth: 9,
          zIndex: 1,
        ),
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
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      initialScrollGesturesEnabled: true,
      initialZoomGesturesEnabled: true,
      initialRotateGesturesEnabled: true,
      initialTiltGesturesEnabled: true,
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

class _AdminRouteFullscreenMap extends StatelessWidget {
  const _AdminRouteFullscreenMap({
    required this.routeName,
    required this.stops,
    required this.roadPath,
    required this.base,
  });

  final String routeName;
  final List<Map<String, dynamic>> stops;
  final List<Map<String, dynamic>> roadPath;
  final Map<String, dynamic>? base;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(routeName)),
    body: Stack(
      children: [
        Positioned.fill(
          child: _AdminRouteMap(stops: stops, roadPath: roadPath, base: base),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12 + MediaQuery.paddingOf(context).bottom,
          child: IgnorePointer(
            child: Card(
              color: Colors.white.withValues(alpha: 0.94),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  '${stops.length} punktów · numery pokazują kolejność przejazdu',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MissedRoutesView extends ConsumerStatefulWidget {
  const _MissedRoutesView();

  @override
  ConsumerState<_MissedRoutesView> createState() => _MissedRoutesViewState();
}

class _MissedRoutesViewState extends ConsumerState<_MissedRoutesView> {
  String? _date;
  final Set<int> _selected = {};

  Future<void> _pickDate(String selectedDate) async {
    final initial = DateTime.tryParse(selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = _isoDate(picked);
      _selected.clear();
    });
  }

  Future<void> _plan(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> items,
  ) async {
    final selectedItems = items
        .where((item) => _selected.contains(_int(item['document_id'])))
        .toList();
    if (selectedItems.isEmpty) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MissedPlannerSheet(
        data: data,
        selectedDate: data['selected_date']?.toString() ?? _date ?? '',
        selectedItems: selectedItems,
      ),
    );
    if (saved == true) {
      setState(_selected.clear);
      ref.invalidate(adminMissedRoutesProvider(_date));
      ref.invalidate(adminMissedRoutesProvider(null));
      ref.invalidate(adminRoutesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pominięte punkty zostały dodane do trasy.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(adminMissedRoutesProvider(_date))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminMissedRoutesProvider(_date)),
        ),
        data: (data) {
          final items = _list(data['items']);
          final selectedDate =
              data['selected_date']?.toString() ??
              _date ??
              _isoDate(DateTime.now());
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(adminMissedRoutesProvider(_date).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Dzień pominięcia'),
                    subtitle: Text(_displayDate(selectedDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickDate(selectedDate),
                  ),
                ),
                if (items.isNotEmpty)
                  CheckboxListTile(
                    value: _selected.length == items.length && items.isNotEmpty,
                    title: const Text('Zaznacz wszystkie z tego dnia'),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selected.addAll(
                          items.map((item) => _int(item['document_id'])),
                        );
                      } else {
                        _selected.clear();
                      }
                    }),
                  ),
                if (items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Brak pominiętych punktów z tego dnia.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                for (final item in items)
                  Card(
                    color: item['status'] == 'missed_closed'
                        ? WntColors.errorSoft
                        : WntColors.warningSoft,
                    child: CheckboxListTile(
                      value: _selected.contains(_int(item['document_id'])),
                      onChanged: (checked) => setState(() {
                        final id = _int(item['document_id']);
                        checked == true
                            ? _selected.add(id)
                            : _selected.remove(id);
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        item['client_name']?.toString() ?? 'Klient',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                              item['location_name'],
                              item['address'],
                              '${item['route_name']} · ${item['status_label']}',
                              _missedProducts(item),
                              if ('${item['driver_note'] ?? ''}'
                                  .trim()
                                  .isNotEmpty)
                                'Uwaga: ${item['driver_note']}',
                            ]
                            .where(
                              (value) => '${value ?? ''}'.trim().isNotEmpty,
                            )
                            .join('\n'),
                      ),
                    ),
                  ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _plan(data, items),
                    icon: const Icon(Icons.route_outlined),
                    label: Text(
                      _selected.isEmpty
                          ? 'Wybierz klientów'
                          : 'Dodaj do trasy (${_selected.length})',
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _MissedPlannerSheet extends ConsumerStatefulWidget {
  const _MissedPlannerSheet({
    required this.data,
    required this.selectedDate,
    required this.selectedItems,
  });

  final Map<String, dynamic> data;
  final String selectedDate;
  final List<Map<String, dynamic>> selectedItems;

  @override
  ConsumerState<_MissedPlannerSheet> createState() =>
      _MissedPlannerSheetState();
}

class _MissedPlannerSheetState extends ConsumerState<_MissedPlannerSheet> {
  late final List<Map<String, dynamic>> routes = _list(
    widget.data['target_routes'],
  );
  late final List<Map<String, dynamic>> drivers = _list(widget.data['drivers']);
  late String mode = routes.isEmpty ? 'new' : 'existing';
  late int routeId = routes.isEmpty ? 0 : _int(routes.first['id']);
  late int driverId = drivers.isEmpty ? 0 : _int(drivers.first['id']);
  late DateTime routeDate = DateTime.now().add(const Duration(days: 1));
  late final TextEditingController routeName = TextEditingController(
    text: 'Powtórka ${_displayDate(widget.selectedDate)}',
  );
  List<Map<String, dynamic>> order = [];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _rebuildOrder();
  }

  @override
  void dispose() {
    routeName.dispose();
    super.dispose();
  }

  void _rebuildOrder() {
    final existing = mode == 'existing'
        ? _list(
            routes.firstWhere(
              (route) => _int(route['id']) == routeId,
              orElse: () => const <String, dynamic>{},
            )['stops'],
          ).map(
            (stop) => <String, dynamic>{
              'kind': 'existing',
              'key':
                  'existing-${stop['client_id']}-${stop['client_location_id']}',
              'name': stop['name'],
            },
          )
        : <Map<String, dynamic>>[];
    order = [
      ...existing,
      ...widget.selectedItems.map(
        (item) => <String, dynamic>{
          'kind': 'new',
          'key': 'new-${item['document_id']}',
          'document_id': _int(item['document_id']),
          'name': [
            item['client_name'],
            item['location_name'],
          ].where((value) => '${value ?? ''}'.trim().isNotEmpty).join(' - '),
        },
      ),
    ];
  }

  void _reorder(int oldIndex, int newIndex) {
    if (order[oldIndex]['kind'] != 'new') return;
    setState(() {
      final item = order.removeAt(oldIndex);
      order.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    if ((mode == 'existing' && routeId < 1) ||
        (mode == 'new' && (driverId < 1 || routeName.text.trim().isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzupełnij trasę i kierowcę.')),
      );
      return;
    }
    final positions = <String, int>{};
    for (var index = 0; index < order.length; index++) {
      if (order[index]['kind'] == 'new') {
        positions['${order[index]['document_id']}'] = index + 1;
      }
    }
    setState(() => saving = true);
    try {
      await ref.read(adminRepositoryProvider).reassignMissedRoutes(
        ref.read(authControllerProvider).session!.token,
        <String, dynamic>{
          'missed_date': widget.selectedDate,
          'document_ids': widget.selectedItems
              .map((item) => _int(item['document_id']))
              .toList(),
          'target_mode': mode,
          'target_route_id': mode == 'existing' ? routeId : null,
          'target_positions': positions,
          'new_route_name': mode == 'new' ? routeName.text.trim() : null,
          'new_scheduled_date': mode == 'new' ? _isoDate(routeDate) : null,
          'new_driver_id': mode == 'new' ? driverId : null,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .94,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Dodaj pominiętych do trasy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'existing',
                    label: Text('Istniejąca trasa'),
                  ),
                  ButtonSegment(value: 'new', label: Text('Nowa trasa')),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => setState(() {
                  mode = selection.first;
                  _rebuildOrder();
                }),
              ),
              const SizedBox(height: 12),
              if (mode == 'existing')
                DropdownButtonFormField<int>(
                  initialValue: routeId == 0 ? null : routeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Trasa'),
                  items: routes
                      .map(
                        (route) => DropdownMenuItem(
                          value: _int(route['id']),
                          child: Text(
                            '${route['date']} - ${route['name']} - ${route['driver'] ?? 'bez kierowcy'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      routeId = value;
                      _rebuildOrder();
                    });
                  },
                )
              else ...[
                TextField(
                  controller: routeName,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa nowej trasy',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data nowej trasy'),
                  subtitle: Text(_displayDate(_isoDate(routeDate))),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: routeDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => routeDate = picked);
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: driverId == 0 ? null : driverId,
                  decoration: const InputDecoration(labelText: 'Kierowca'),
                  items: drivers
                      .map(
                        (driver) => DropdownMenuItem(
                          value: _int(driver['id']),
                          child: Text('${driver['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => driverId = value ?? 0),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Kolejność na trasie',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Obecne punkty są wyszarzone i zablokowane. Przeciągaj tylko dodawanych klientów.',
                style: TextStyle(color: WntColors.muted),
              ),
              const SizedBox(height: 10),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: order.length,
                onReorderItem: _reorder,
                itemBuilder: (context, index) {
                  final item = order[index];
                  final existing = item['kind'] == 'existing';
                  return Card(
                    key: ValueKey(item['key']),
                    color: existing ? Colors.grey.shade200 : Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(
                        item['name']?.toString() ?? 'Klient',
                        style: TextStyle(
                          color: existing ? Colors.grey.shade600 : null,
                        ),
                      ),
                      trailing: existing
                          ? const Icon(Icons.lock_outline)
                          : ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route_outlined),
                label: const Text('Zapisz punkty na trasie'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RouteFilters extends StatelessWidget {
  const _RouteFilters({
    required this.selected,
    required this.tabs,
    required this.onChanged,
  });

  final String selected;
  final List<(String, String, int)> tabs;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final tab in tabs) ...[
          ChoiceChip(
            selected: selected == tab.$1,
            label: Text('${tab.$2}  ${tab.$3}'),
            onSelected: (_) => onChanged(tab.$1),
          ),
          const SizedBox(width: 8),
        ],
      ],
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

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _displayDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year.toString().padLeft(4, '0')}';
}

String _missedProducts(Map<String, dynamic> item) {
  final products = [..._list(item['products']), ..._list(item['packages'])];
  if (products.isEmpty) return 'Bez przypisanych produktów';
  return products
      .map(
        (row) => '${row['name']} × ${row['quantity']} ${row['unit'] ?? 'szt.'}',
      )
      .join(', ');
}
