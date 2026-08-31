import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/theme/wnt_colors.dart';

class DriverNavigationScreen extends StatefulWidget {
  const DriverNavigationScreen({
    required this.destinations,
    required this.title,
    super.key,
  });

  final List<DriverNavigationDestination> destinations;
  final String title;

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  String _status = 'Uruchamianie nawigacji...';
  bool _sessionReady = false;
  bool _ready = false;
  bool _arrived = false;
  bool _starting = false;
  Timer? _fallbackTimer;
  StreamSubscription<OnArrivalEvent>? _arrivalSubscription;
  GoogleNavigationViewController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareSession());
    _fallbackTimer = Timer(const Duration(seconds: 45), () async {
      if (!mounted || _ready) return;
      setState(() => _status = 'Moduł nawigacji Google nie odpowiedział.');
      try {
        throw Exception('Nawigacja wewnętrzna nie odpowiedziała.');
      } catch (error) {
        if (mounted) {
          setState(
            () => _status = error.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    });
  }

  Future<void> _prepareSession() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Włącz lokalizację GPS w telefonie.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Aplikacja nie ma dostępu do lokalizacji.');
      }

      final accepted =
          await GoogleMapsNavigator.areTermsAccepted() ||
          await GoogleMapsNavigator.showTermsAndConditionsDialog(
            'Nawigacja Woda na telefon',
            'Woda na telefon',
          );
      if (!accepted) {
        throw Exception('Warunki nawigacji nie zostały zaakceptowane.');
      }

      await GoogleMapsNavigator.initializeNavigationSession().timeout(
        const Duration(seconds: 40),
      );
      await _arrivalSubscription?.cancel();
      _arrivalSubscription = GoogleMapsNavigator.setOnArrivalListener((_) {
        if (mounted) setState(() => _arrived = true);
      });
      if (mounted) {
        setState(() {
          _sessionReady = true;
          _status = 'Przygotowywanie mapy...';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _start(GoogleNavigationViewController controller) async {
    if (_starting || _ready) return;
    _starting = true;
    try {
      _controller = controller;
      final destinations = widget.destinations
          .where(
            (item) =>
                item.latitude.isFinite &&
                item.longitude.isFinite &&
                item.latitude >= -90 &&
                item.latitude <= 90 &&
                item.longitude >= -180 &&
                item.longitude <= 180 &&
                !(item.latitude == 0 && item.longitude == 0),
          )
          .toList();
      if (destinations.isEmpty) {
        throw Exception('Brak poprawnych współrzędnych punktów trasy.');
      }
      if (!_sessionReady) {
        throw Exception(_status);
      }
      await controller.setNavigationUIEnabled(true);
      final status = await GoogleMapsNavigator.setDestinations(
        Destinations(
          waypoints: destinations
              .map(
                (item) => NavigationWaypoint.withLatLngTarget(
                  title: item.title,
                  target: LatLng(
                    latitude: item.latitude,
                    longitude: item.longitude,
                  ),
                ),
              )
              .toList(),
          displayOptions: NavigationDisplayOptions(
            showDestinationMarkers: true,
          ),
        ),
      ).timeout(const Duration(seconds: 30));
      if (status != NavigationRouteStatus.statusOk) {
        throw Exception('Google nie wyznaczyło trasy do tego punktu.');
      }
      await GoogleMapsNavigator.startGuidance().timeout(
        const Duration(seconds: 20),
      );
      if (mounted) {
        _fallbackTimer?.cancel();
        setState(() => _ready = true);
      }
      await controller
          .followMyLocation(CameraPerspective.tilted)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _close() async {
    _fallbackTimer?.cancel();
    await _arrivalSubscription?.cancel();
    try {
      await GoogleMapsNavigator.cleanup();
    } catch (_) {
      // A session may not exist when initialization failed.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: landscape
            ? null
            : AppBar(
                title: Text(widget.title),
                leading: IconButton(
                  tooltip: 'Zakończ nawigację',
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                ),
              ),
        body: Stack(
          children: [
            if (_sessionReady)
              Positioned.fill(
                child: GoogleMapsNavigationView(
                  onViewCreated: _start,
                  initialNavigationUIEnabledPreference:
                      NavigationUIEnabledPreference.automatic,
                ),
              ),
            if (!_ready)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_status)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_ready)
              Positioned(
                right: 14,
                bottom: 14,
                child: FloatingActionButton.small(
                  tooltip: 'Śledź pojazd',
                  onPressed: () =>
                      _controller?.followMyLocation(CameraPerspective.tilted),
                  child: const Icon(Icons.my_location),
                ),
              ),
            if (landscape)
              Positioned(
                left: 14,
                top: 14,
                child: FloatingActionButton.small(
                  heroTag: 'close-navigation',
                  tooltip: 'Zakończ nawigację',
                  onPressed: _close,
                  child: const Icon(Icons.close),
                ),
              ),
            if (landscape)
              Positioned(
                right: 70,
                bottom: 14,
                child: FilledButton.icon(
                  onPressed: _arrived
                      ? () async {
                          await GoogleMapsNavigator.continueToNextDestination();
                          await _controller?.followMyLocation(
                            CameraPerspective.tilted,
                          );
                          if (mounted) setState(() => _arrived = false);
                        }
                      : _close,
                  icon: Icon(
                    _arrived
                        ? Icons.skip_next_outlined
                        : Icons.stop_circle_outlined,
                  ),
                  label: Text(_arrived ? 'Następny punkt' : 'Zakończ'),
                ),
              ),
          ],
        ),
        bottomNavigationBar: landscape
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: WntColors.line)),
                  ),
                  child: FilledButton.icon(
                    onPressed: _arrived
                        ? () async {
                            await GoogleMapsNavigator.continueToNextDestination();
                            await _controller?.followMyLocation(
                              CameraPerspective.tilted,
                            );
                            if (mounted) setState(() => _arrived = false);
                          }
                        : _close,
                    icon: Icon(
                      _arrived
                          ? Icons.skip_next_outlined
                          : Icons.stop_circle_outlined,
                    ),
                    label: Text(
                      _arrived ? 'Następny punkt' : 'Zakończ nawigację',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class DriverNavigationDestination {
  const DriverNavigationDestination({
    required this.latitude,
    required this.longitude,
    required this.title,
  });

  final double latitude;
  final double longitude;
  final String title;
}
