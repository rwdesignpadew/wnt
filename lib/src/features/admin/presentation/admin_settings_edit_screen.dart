import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';

class AdminSettingsEditScreen extends ConsumerStatefulWidget {
  const AdminSettingsEditScreen({required this.kind, this.item, super.key});

  final String kind;
  final Map<String, dynamic>? item;

  @override
  ConsumerState<AdminSettingsEditScreen> createState() =>
      _AdminSettingsEditScreenState();
}

class _AdminSettingsEditScreenState
    extends ConsumerState<AdminSettingsEditScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;
  bool _active = true;
  int? _defaultDriverId;

  bool get _isDriver => widget.kind == 'drivers';
  int? get _id => _intOrNull(widget.item?['id']);

  @override
  void initState() {
    super.initState();
    _active = widget.item == null || _bool(widget.item?['is_active']);
    _defaultDriverId = _intOrNull(widget.item?['default_driver_id']);
    if (!_isDriver && widget.item == null) {
      _controller('radius_km').text = '50';
      _controller('bearing_tolerance').text = '45';
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: widget.item?[key]?.toString() ?? ''),
  );

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      final response = _isDriver
          ? await repository.saveDriver(token, _id, {
              'name': _controller('title').text.trim(),
              'email': _controller('subtitle').text.trim(),
              'phone': _controller('phone').text.trim(),
              'region_id': _intOrNull(_controller('region_id').text),
              'gps_vehicle_id': _controller('gps_vehicle_id').text.trim(),
              'gps_vehicle_name': _controller('gps_vehicle_name').text.trim(),
              'vehicle_registration': _controller(
                'vehicle_registration',
              ).text.trim(),
              'password': _controller('password').text,
              'is_active': _active,
            })
          : await repository.saveRegion(token, _id, {
              'name': _controller('title').text.trim(),
              'slug': _controller('slug').text.trim(),
              'base_lat': _numberOrNull(_controller('base_lat').text),
              'base_lng': _numberOrNull(_controller('base_lng').text),
              'target_lat': _numberOrNull(_controller('target_lat').text),
              'target_lng': _numberOrNull(_controller('target_lng').text),
              'radius_km': _intOrNull(_controller('radius_km').text),
              'bearing_tolerance': _intOrNull(
                _controller('bearing_tolerance').text,
              ),
              'default_driver_id': _defaultDriverId,
              'is_active': _active,
            });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Zapisano.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = _id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isDriver ? 'Usunąć kierowcę?' : 'Usunąć region?'),
        content: const Text(
          'Jeżeli rekord jest używany, serwer zablokuje usunięcie i pozwoli go wyłączyć.',
        ),
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
    if (confirmed != true || !mounted) return;
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      _isDriver
          ? await repository.deleteDriver(token, id)
          : await repository.deleteRegion(token, id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _isDriver
            ? _id == null
                  ? 'Nowy kierowca'
                  : 'Edytuj kierowcę'
            : _id == null
            ? 'Nowy region'
            : 'Edytuj region',
      ),
      actions: [
        if (_id != null)
          IconButton(
            tooltip: 'Usuń',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: WntColors.error),
          ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Zapisywanie...' : 'Zapisz'),
        ),
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _isDriver ? _driverFields() : _regionFields(),
      ),
    ),
  );

  List<Widget> _driverFields() => [
    _field('title', 'Imię i nazwisko', required: true),
    _field(
      'subtitle',
      'Email logowania',
      required: true,
      keyboard: TextInputType.emailAddress,
    ),
    _field('phone', 'Telefon', keyboard: TextInputType.phone),
    _field('region_id', 'ID regionu', keyboard: TextInputType.number),
    _field('gps_vehicle_id', 'ID pojazdu GPS'),
    _field('gps_vehicle_name', 'Nazwa pojazdu GPS'),
    _field('vehicle_registration', 'Numer rejestracyjny'),
    _field(
      'password',
      _id == null ? 'Hasło' : 'Nowe hasło (pozostaw puste bez zmiany)',
      required: _id == null,
      obscure: true,
    ),
    SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text('Kierowca aktywny'),
      value: _active,
      onChanged: (value) => setState(() => _active = value),
    ),
  ];

  List<Widget> _regionFields() {
    final operations = ref.watch(adminOperationsProvider).valueOrNull ?? {};
    final drivers = operations['drivers'] is List
        ? (operations['drivers'] as List)
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList()
        : <Map<String, dynamic>>[];
    return [
      _field('title', 'Nazwa regionu', required: true),
      _field('slug', 'Identyfikator regionu', required: true),
      Row(
        children: [
          Expanded(child: _field('base_lat', 'Baza: szerokość')),
          const SizedBox(width: 8),
          Expanded(child: _field('base_lng', 'Baza: długość')),
        ],
      ),
      Row(
        children: [
          Expanded(child: _field('target_lat', 'Kierunek: szerokość')),
          const SizedBox(width: 8),
          Expanded(child: _field('target_lng', 'Kierunek: długość')),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: _field(
              'radius_km',
              'Promień (km)',
              required: true,
              keyboard: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _field(
              'bearing_tolerance',
              'Tolerancja kierunku',
              required: true,
              keyboard: TextInputType.number,
            ),
          ),
        ],
      ),
      DropdownButtonFormField<int?>(
        initialValue:
            drivers.any((item) => _intOrNull(item['id']) == _defaultDriverId)
            ? _defaultDriverId
            : null,
        decoration: const InputDecoration(labelText: 'Domyślny kierowca'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Brak')),
          ...drivers.map(
            (item) => DropdownMenuItem<int?>(
              value: _intOrNull(item['id']),
              child: Text(item['title']?.toString() ?? 'Kierowca'),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _defaultDriverId = value),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Region aktywny'),
        value: _active,
        onChanged: (value) => setState(() => _active = value),
      ),
    ];
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool obscure = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _controller(key),
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) =>
                value?.trim().isEmpty == true ? 'To pole jest wymagane.' : null
          : null,
    ),
  );
}

int? _intOrNull(dynamic value) {
  final parsed = int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _numberOrNull(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

bool _bool(dynamic value) => value == true || value == 1 || value == '1';
