import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_bottom_navigation.dart';

class AdminClientTrialsScreen extends ConsumerStatefulWidget {
  const AdminClientTrialsScreen({super.key});

  @override
  ConsumerState<AdminClientTrialsScreen> createState() =>
      _AdminClientTrialsScreenState();
}

class _AdminClientTrialsScreenState
    extends ConsumerState<AdminClientTrialsScreen> {
  String _status = 'open';
  String _search = '';

  AdminClientTrialsQuery get _query => (status: _status, search: _search);

  Future<void> _decide(
    Map<String, dynamic> trial,
    Map<String, dynamic> data,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TrialDecisionSheet(trial: trial, data: data),
    );
    if (changed == true) ref.invalidate(adminClientTrialsProvider);
  }

  Future<void> _create(Map<String, dynamic> data) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewClientTrialSheet(data: data),
    );
    if (changed == true) ref.invalidate(adminClientTrialsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminClientTrialsProvider(_query));
    final loadedData = state.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klienci testowi'),
        actions: [
          IconButton(
            tooltip: 'Dodaj testy obecnemu klientowi',
            onPressed: loadedData == null ? null : () => _create(loadedData),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      bottomNavigationBar: adminBottomNavigation(context, ref),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminClientTrialsProvider),
        ),
        data: (data) {
          final items = _maps(data['items']);
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(adminClientTrialsProvider(_query).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Szukaj klienta',
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Otwarte')),
                    DropdownMenuItem(
                      value: 'planned',
                      child: Text('Do wydania'),
                    ),
                    DropdownMenuItem(value: 'active', child: Text('Test trwa')),
                    DropdownMenuItem(
                      value: 'expired',
                      child: Text('Po terminie'),
                    ),
                    DropdownMenuItem(
                      value: 'pickup_pending',
                      child: Text('Odbiór zaplanowany'),
                    ),
                    DropdownMenuItem(
                      value: 'converted',
                      child: Text('Płatna dzierżawa'),
                    ),
                    DropdownMenuItem(
                      value: 'returned',
                      child: Text('Odebrane'),
                    ),
                    DropdownMenuItem(value: 'all', child: Text('Wszystkie')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'open'),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Brak klientów testowych dla wybranego filtra.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                for (final trial in items) ...[
                  _TrialCard(
                    trial: trial,
                    onDecide: _canResolve(trial)
                        ? () => _decide(trial, data)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NewClientTrialSheet extends ConsumerStatefulWidget {
  const _NewClientTrialSheet({required this.data});

  final Map<String, dynamic> data;

  @override
  ConsumerState<_NewClientTrialSheet> createState() =>
      _NewClientTrialSheetState();
}

class _NewClientTrialSheetState extends ConsumerState<_NewClientTrialSheet> {
  int? _clientId;
  int? _locationId;
  int? _routeId;
  int? _driverId;
  String _routeMode = 'existing';
  bool _saving = false;
  final _duration = TextEditingController(text: '14');
  final _notes = TextEditingController();
  final _routeName = TextEditingController(text: 'Wydanie testów');
  final _date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final List<Map<String, int>> _items = [
    {'product_id': 0, 'quantity': 1},
  ];

  List<Map<String, dynamic>> get _clients => _maps(widget.data['clients']);
  List<Map<String, dynamic>> get _products => _maps(widget.data['products']);
  List<Map<String, dynamic>> get _locations {
    final client = _clients.where((item) => _int(item['id']) == _clientId);
    return client.isEmpty ? [] : _maps(client.first['locations']);
  }

  @override
  void dispose() {
    _duration.dispose();
    _notes.dispose();
    _routeName.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final duration = int.tryParse(_duration.text);
    final selectedItems = _items
        .where((item) => (item['product_id'] ?? 0) > 0)
        .toList();
    if (_clientId == null || _locationId == null) {
      _message('Wybierz klienta i lokalizację.');
      return;
    }
    if (duration == null || duration < 1) {
      _message('Podaj prawidłową liczbę dni testów.');
      return;
    }
    if (selectedItems.isEmpty ||
        selectedItems.any((item) => (item['quantity'] ?? 0) < 1)) {
      _message('Wybierz co najmniej jedną pozycję i jej ilość.');
      return;
    }
    if (selectedItems.map((item) => item['product_id']).toSet().length !=
        selectedItems.length) {
      _message('Ten sam produkt może wystąpić tylko raz.');
      return;
    }
    if (_routeMode == 'existing' && _routeId == null) {
      _message('Wybierz istniejącą trasę.');
      return;
    }
    if (_routeMode == 'new' && _driverId == null) {
      _message('Wybierz kierowcę dla nowej trasy.');
      return;
    }

    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .createClientTrial(token, {
            'client_id': _clientId,
            'client_location_id': _locationId,
            'duration_days': duration,
            'notes': _notes.text.trim(),
            'items': selectedItems,
            'route_mode': _routeMode,
            'delivery_route_id': _routeMode == 'existing' ? _routeId : null,
            'route_name': _routeMode == 'new' ? _routeName.text.trim() : null,
            'scheduled_date': _routeMode == 'new' ? _date.text.trim() : null,
            'driver_id': _routeMode == 'new' ? _driverId : null,
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message'] ?? 'Dodano testy.'}'),
          backgroundColor: WntColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), backgroundColor: WntColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = _maps(widget.data['routes']);
    final drivers = _maps(widget.data['drivers']);
    return FractionallySizedBox(
      heightFactor: .95,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dodaj testy obecnemu klientowi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Wybierz klienta, lokalizację i co otrzyma bez opłaty.',
                        style: TextStyle(color: WntColors.muted),
                      ),
                    ],
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
              padding: const EdgeInsets.all(16),
              children: [
                DropdownMenu<int>(
                  width: MediaQuery.sizeOf(context).width - 32,
                  enableFilter: true,
                  enableSearch: true,
                  label: const Text('Wyszukaj i wybierz klienta'),
                  dropdownMenuEntries: _clients
                      .map(
                        (client) => DropdownMenuEntry<int>(
                          value: _int(client['id']),
                          label: '${client['name']}',
                        ),
                      )
                      .toList(),
                  onSelected: (value) => setState(() {
                    _clientId = value;
                    final locations = _locations;
                    _locationId = locations.isEmpty
                        ? null
                        : _int(locations.first['id']);
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('trial-location-$_clientId-$_locationId'),
                  initialValue: _locationId,
                  decoration: const InputDecoration(labelText: 'Lokalizacja'),
                  items: _locations
                      .map(
                        (location) => DropdownMenuItem<int>(
                          value: _int(location['id']),
                          child: Text(
                            '${location['name']} — ${location['address'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _locationId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Liczba dni testów',
                    suffixText: 'dni',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Co klient dostaje',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _items.add({'product_id': 0, 'quantity': 1}),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj pozycję'),
                    ),
                  ],
                ),
                for (var index = 0; index < _items.length; index++) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: (_items[index]['product_id'] ?? 0) > 0
                                ? _items[index]['product_id']
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Produkt / sprzęt',
                            ),
                            items: _products
                                .map(
                                  (product) => DropdownMenuItem<int>(
                                    value: _int(product['id']),
                                    child: Text(
                                      '${product['name']} (stan ${_int(product['stock'])})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(
                              () => _items[index]['product_id'] = value ?? 0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      '${_items[index]['quantity'] ?? 1}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Ilość',
                                  ),
                                  onChanged: (value) =>
                                      _items[index]['quantity'] =
                                          int.tryParse(value) ?? 0,
                                ),
                              ),
                              IconButton(
                                onPressed: _items.length == 1
                                    ? null
                                    : () => setState(
                                        () => _items.removeAt(index),
                                      ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: WntColors.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'existing',
                      label: Text('Istniejąca trasa'),
                    ),
                    ButtonSegment(value: 'new', label: Text('Nowa trasa')),
                  ],
                  selected: {_routeMode},
                  onSelectionChanged: (value) =>
                      setState(() => _routeMode = value.first),
                ),
                const SizedBox(height: 12),
                if (_routeMode == 'existing')
                  DropdownButtonFormField<int>(
                    initialValue: _routeId,
                    decoration: const InputDecoration(labelText: 'Trasa'),
                    items: routes
                        .map(
                          (route) => DropdownMenuItem<int>(
                            value: _int(route['id']),
                            child: Text(
                              '${route['date']} — ${route['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _routeId = value),
                  )
                else ...[
                  TextField(
                    controller: _routeName,
                    decoration: const InputDecoration(labelText: 'Nazwa trasy'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _date,
                    decoration: const InputDecoration(
                      labelText: 'Data (RRRR-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _driverId,
                    decoration: const InputDecoration(labelText: 'Kierowca'),
                    items: drivers
                        .map(
                          (driver) => DropdownMenuItem<int>(
                            value: _int(driver['id']),
                            child: Text('${driver['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _driverId = value),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Uwagi do testów',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving ? 'Zapisywanie...' : 'Dodaj testy do trasy',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({required this.trial, this.onDecide});

  final Map<String, dynamic> trial;
  final VoidCallback? onDecide;

  @override
  Widget build(BuildContext context) {
    final overdue = _bool(trial['is_overdue']);
    final items = _maps(trial['items']);
    return Card(
      color: overdue ? WntColors.errorSoft : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: overdue ? WntColors.error : WntColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trial['client_name'] ?? 'Klient'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${trial['location_name'] ?? 'Główna lokalizacja'} — ${trial['location_address'] ?? ''}',
                        style: const TextStyle(color: WntColors.muted),
                      ),
                    ],
                  ),
                ),
                _StatusChip(trial: trial),
              ],
            ),
            const Divider(height: 24),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${item['name']} — ${_int(item['quantity'])} szt.${_bool(item['is_rental']) ? ' · sprzęt do zwrotu' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              trial['starts_on'] == null
                  ? '${_int(trial['duration_days'])} dni od podpisanego wydania'
                  : '${trial['starts_on']} — ${trial['ends_on']}',
              style: TextStyle(
                color: overdue ? WntColors.error : WntColors.muted,
                fontWeight: overdue ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            if ('${trial['issue_route_name'] ?? ''}'.isNotEmpty)
              Text('Trasa wydania: ${trial['issue_route_name']}'),
            if ('${trial['resolution_route_name'] ?? ''}'.isNotEmpty)
              Text('Trasa odbioru: ${trial['resolution_route_name']}'),
            if (onDecide != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onDecide,
                icon: const Icon(Icons.rule_outlined),
                label: const Text('Zdecyduj: odbiór lub dzierżawa'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.trial});
  final Map<String, dynamic> trial;

  @override
  Widget build(BuildContext context) {
    final overdue = _bool(trial['is_overdue']);
    final status = '${trial['status']}';
    final label = switch (status) {
      'planned' => 'Do wydania',
      'active' => 'Test trwa',
      'expired' => 'Po terminie',
      'pickup_pending' => 'Odbiór',
      'converted' => 'Dzierżawa',
      'returned' => 'Odebrane',
      _ => status,
    };
    return Chip(
      label: Text(label),
      backgroundColor: overdue ? WntColors.error : WntColors.brandSoft,
      labelStyle: TextStyle(
        color: overdue ? Colors.white : WntColors.brand,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TrialDecisionSheet extends ConsumerStatefulWidget {
  const _TrialDecisionSheet({required this.trial, required this.data});

  final Map<String, dynamic> trial;
  final Map<String, dynamic> data;

  @override
  ConsumerState<_TrialDecisionSheet> createState() =>
      _TrialDecisionSheetState();
}

class _TrialDecisionSheetState extends ConsumerState<_TrialDecisionSheet> {
  String _decision = 'convert';
  String _routeMode = 'existing';
  int? _routeId;
  int? _driverId;
  bool _saving = false;
  late final TextEditingController _routeName;
  late final TextEditingController _date;
  final Map<int, TextEditingController> _prices = {};

  @override
  void initState() {
    super.initState();
    _routeName = TextEditingController(text: 'Odbiór testów');
    _date = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    for (final item in _maps(
      widget.trial['items'],
    ).where((item) => _bool(item['is_rental']))) {
      _prices[_int(item['id'])] = TextEditingController(
        text: '${item['price'] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    _routeName.dispose();
    _date.dispose();
    for (final controller in _prices.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      Map<String, dynamic> response;
      if (_decision == 'convert') {
        final prices = <int, double>{};
        for (final entry in _prices.entries) {
          final value = double.tryParse(entry.value.text.replaceAll(',', '.'));
          if (value == null || value < 0) {
            throw StateError('Ustaw cenę dla każdego sprzętu.');
          }
          prices[entry.key] = value;
        }
        if (prices.isEmpty) {
          throw StateError('Ten test nie zawiera sprzętu do dzierżawy.');
        }
        response = await repository.convertClientTrial(
          token,
          _int(widget.trial['id']),
          prices,
        );
      } else {
        if (_routeMode == 'existing' && _routeId == null) {
          throw StateError('Wybierz trasę odbioru.');
        }
        if (_routeMode == 'new' && _driverId == null) {
          throw StateError('Wybierz kierowcę.');
        }
        response = await repository
            .pickupClientTrial(token, _int(widget.trial['id']), {
              'route_mode': _routeMode,
              'delivery_route_id': _routeMode == 'existing' ? _routeId : null,
              'route_name': _routeMode == 'new' ? _routeName.text.trim() : null,
              'scheduled_date': _routeMode == 'new' ? _date.text.trim() : null,
              'driver_id': _routeMode == 'new' ? _driverId : null,
            });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message'] ?? 'Zapisano.'}'),
          backgroundColor: WntColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = _maps(widget.data['routes']);
    final drivers = _maps(widget.data['drivers']);
    final rentalItems = _maps(
      widget.trial['items'],
    ).where((item) => _bool(item['is_rental'])).toList();
    return FractionallySizedBox(
      heightFactor: .92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Zakończenie testów',
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'convert',
                      label: Text('Zostaje'),
                      icon: Icon(Icons.handshake_outlined),
                    ),
                    ButtonSegment(
                      value: 'pickup',
                      label: Text('Odbieramy'),
                      icon: Icon(Icons.assignment_return_outlined),
                    ),
                  ],
                  selected: {_decision},
                  onSelectionChanged: (value) =>
                      setState(() => _decision = value.first),
                ),
                const SizedBox(height: 16),
                if (_decision == 'convert')
                  for (final item in rentalItems) ...[
                    Text(
                      '${item['name']} — ${_int(item['quantity'])} szt.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _prices[_int(item['id'])],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cena miesięczna netto za 1 szt.',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ]
                else ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'existing',
                        label: Text('Istniejąca trasa'),
                      ),
                      ButtonSegment(value: 'new', label: Text('Nowa trasa')),
                    ],
                    selected: {_routeMode},
                    onSelectionChanged: (value) =>
                        setState(() => _routeMode = value.first),
                  ),
                  const SizedBox(height: 12),
                  if (_routeMode == 'existing')
                    DropdownButtonFormField<int>(
                      initialValue: _routeId,
                      decoration: const InputDecoration(
                        labelText: 'Trasa odbioru',
                      ),
                      items: [
                        for (final route in routes)
                          DropdownMenuItem(
                            value: _int(route['id']),
                            child: Text(
                              '${route['date']} — ${route['name']} — ${route['driver'] ?? ''}',
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _routeId = value),
                    )
                  else ...[
                    TextField(
                      controller: _routeName,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa trasy',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _date,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Data odbioru',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(_date.text) ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (selected != null) {
                          _date.text = selected.toIso8601String().substring(
                            0,
                            10,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _driverId,
                      decoration: const InputDecoration(labelText: 'Kierowca'),
                      items: [
                        for (final driver in drivers)
                          DropdownMenuItem(
                            value: _int(driver['id']),
                            child: Text('${driver['name']}'),
                          ),
                      ],
                      onChanged: (value) => setState(() => _driverId = value),
                    ),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Zapisywanie...' : 'Zapisz decyzję'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _canResolve(Map<String, dynamic> trial) =>
    const {'active', 'expired'}.contains('${trial['status']}');

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : <Map<String, dynamic>>[];

int _int(dynamic value) => int.tryParse('$value') ?? 0;

bool _bool(dynamic value) => value == true || value == 1 || value == '1';
