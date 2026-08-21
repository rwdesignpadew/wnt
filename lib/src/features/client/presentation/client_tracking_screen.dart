import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../application/client_providers.dart';

class ClientTrackingScreen extends ConsumerStatefulWidget {
  const ClientTrackingScreen({super.key});

  @override
  ConsumerState<ClientTrackingScreen> createState() =>
      _ClientTrackingScreenState();
}

class _ClientTrackingScreenState extends ConsumerState<ClientTrackingScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => ref.invalidate(clientTrackingProvider),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(clientTrackingProvider);
    return tracking.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(clientTrackingProvider),
      ),
      data: (response) {
        final data = response['tracking'];
        if (data is! Map) {
          return const EmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Brak aktywnej dostawy',
            message:
                'Po zaplanowaniu zamówienia zobaczysz tutaj status i pojazd.',
          );
        }
        final item = data.cast<String, dynamic>();
        final driver = item['driver'] is Map
            ? (item['driver'] as Map).cast<String, dynamic>()
            : null;
        final destination = item['destination'] is Map
            ? (item['destination'] as Map).cast<String, dynamic>()
            : null;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientTrackingProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Twoja dostawa',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusBadge(item['status']?.toString() ?? 'Zaplanowana'),
                      const SizedBox(height: 14),
                      Text(
                        item['order_number']?.toString() ?? 'Zamówienie',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(item['address']?.toString() ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (driver != null && destination != null) ...[
                Text(
                  'Śledzenie samochodu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 300,
                    child: _TrackingMap(
                      key: ValueKey(driver['recorded_at']),
                      driver: driver,
                      destination: destination,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: _InfoLine(
                      icon: Icons.map_outlined,
                      label: 'Mapa dostawy',
                      value:
                          'Brak aktualnej pozycji samochodu lub współrzędnych dostawy',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _InfoLine(
                        icon: Icons.person_outline,
                        label: 'Kierowca',
                        value:
                            item['driver_name']?.toString() ??
                            'Jeszcze nie przypisano',
                      ),
                      const Divider(height: 24),
                      _InfoLine(
                        icon: Icons.local_shipping_outlined,
                        label: 'Pojazd',
                        value: item['vehicle']?.toString() ?? 'Brak danych',
                      ),
                      const Divider(height: 24),
                      _InfoLine(
                        icon: Icons.gps_fixed,
                        label: 'GPS samochodu (MyCar)',
                        value:
                            driver?['recorded_at']?.toString() ??
                            'Brak sygnału',
                      ),
                      const Divider(height: 24),
                      _InfoLine(
                        icon: Icons.schedule_outlined,
                        label: 'Szacowana dostawa',
                        value: item['eta_minutes'] == null
                            ? 'Pojawi się po uruchomieniu trasy'
                            : 'około ${item['eta_at']} (${item['eta_minutes']} min)',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackingMap extends StatefulWidget {
  const _TrackingMap({
    super.key,
    required this.driver,
    required this.destination,
  });

  final Map<String, dynamic> driver;
  final Map<String, dynamic> destination;

  @override
  State<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<_TrackingMap> {
  Future<void> _onCreated(GoogleMapViewController controller) async {
    final driverPosition = LatLng(
      latitude: (widget.driver['lat'] as num).toDouble(),
      longitude: (widget.driver['lng'] as num).toDouble(),
    );
    final destinationPosition = LatLng(
      latitude: (widget.destination['lat'] as num).toDouble(),
      longitude: (widget.destination['lng'] as num).toDouble(),
    );
    await controller.addMarkers([
      MarkerOptions(
        position: driverPosition,
        infoWindow: const InfoWindow(title: 'Samochód dostawczy'),
        zIndex: 2,
      ),
      MarkerOptions(
        position: destinationPosition,
        infoWindow: InfoWindow(
          title: 'Miejsce dostawy',
          snippet: widget.destination['address']?.toString(),
        ),
      ),
    ]);
    await controller.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            latitude: driverPosition.latitude < destinationPosition.latitude
                ? driverPosition.latitude
                : destinationPosition.latitude,
            longitude: driverPosition.longitude < destinationPosition.longitude
                ? driverPosition.longitude
                : destinationPosition.longitude,
          ),
          northeast: LatLng(
            latitude: driverPosition.latitude > destinationPosition.latitude
                ? driverPosition.latitude
                : destinationPosition.latitude,
            longitude: driverPosition.longitude > destinationPosition.longitude
                ? driverPosition.longitude
                : destinationPosition.longitude,
          ),
        ),
        padding: 70,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMapsMapView(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          latitude: (widget.driver['lat'] as num).toDouble(),
          longitude: (widget.driver['lng'] as num).toDouble(),
        ),
        zoom: 13,
      ),
      onViewCreated: _onCreated,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WntColors.brandSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          value,
          style: const TextStyle(
            color: WntColors.brand,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: WntColors.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
              ),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}
