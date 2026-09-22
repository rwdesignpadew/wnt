import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_bottom_navigation.dart';

class AdminRouteEditScreen extends ConsumerStatefulWidget {
  const AdminRouteEditScreen({this.id, this.initialClientId, super.key});

  final int? id;
  final int? initialClientId;

  @override
  ConsumerState<AdminRouteEditScreen> createState() =>
      _AdminRouteEditScreenState();
}

class _AdminRouteEditScreenState extends ConsumerState<AdminRouteEditScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _interval = TextEditingController(text: '14');
  final _pointSearch = TextEditingController();
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _stops = [];
  DateTime _date = DateTime.now();
  int _driverId = 0;
  String _region = '';
  String _status = 'planned';
  bool _recurring = false;
  bool _loading = true;
  bool _saving = false;
  bool _optimizing = false;
  bool _dirty = false;
  int _step = 0;
  String _pointQuery = '';
  final Set<String> _expandedStops = <String>{};
  int? _initialProductsStopIndex;

  @override
  void initState() {
    super.initState();
    _name.addListener(_markDirty);
    _notes.addListener(_markDirty);
    _interval.addListener(_markDirty);
    _pointSearch.addListener(() {
      if (mounted) setState(() => _pointQuery = _pointSearch.text.trim());
    });
    _load();
  }

  @override
  void dispose() {
    _name.removeListener(_markDirty);
    _notes.removeListener(_markDirty);
    _interval.removeListener(_markDirty);
    _name.dispose();
    _notes.dispose();
    _interval.dispose();
    _pointSearch.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_loading && mounted && !_dirty) setState(() => _dirty = true);
  }

  void _change(VoidCallback callback) {
    setState(() {
      callback();
      _dirty = true;
    });
  }

  Future<void> _load() async {
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      final responses = await Future.wait([
        repository.routeOptions(token),
        if (widget.id != null) repository.route(token, widget.id!),
      ]);
      final options = responses.first;
      _clients = _maps(options['clients']);
      _products = _maps(options['products']);
      _drivers = _maps(options['drivers']);
      _regions = _maps(options['regions']);
      if (widget.id == null) {
        _name.clear();
      } else {
        final route = _map(responses[1]['route']);
        _name.text = '${route['name'] ?? ''}';
        _notes.text = '${route['notes'] ?? ''}';
        _driverId = _int(route['driver_id']);
        _region = '${route['region'] ?? ''}';
        _status = '${route['status'] ?? 'planned'}';
        _recurring = route['is_recurring'] == true;
        _interval.text = '${route['recurrence_interval_days'] ?? 14}';
        _date = _parseDate('${route['scheduled_date'] ?? ''}');
        _stops = _maps(route['stops'])
            .map(
              (stop) => <String, dynamic>{
                'client_id': _int(stop['client_id']),
                'location_id': _locationId(stop),
                'products': _intMap(stop['products']),
                'packages': _intMap(stop['packages']),
                'package_components': _nestedIntMap(stop['package_components']),
                'sanitization_equipment': _strings(
                  stop['sanitization_equipment'],
                ),
              },
            )
            .toList();
        _step = 1;
      }
      _prepareInitialClient();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _dirty = false;
        });
        final stopIndex = _initialProductsStopIndex;
        if (stopIndex != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _editProducts(stopIndex);
          });
        }
      }
    }
  }

  void _prepareInitialClient() {
    final initialClientId = widget.initialClientId;
    if (initialClientId == null) return;

    final existingIndex = _stops.indexWhere(
      (stop) => _int(stop['client_id']) == initialClientId,
    );
    if (existingIndex >= 0) {
      _initialProductsStopIndex = existingIndex;
      _step = 1;
      _expandedStops.add(_stopKey(_stops[existingIndex]));
      return;
    }

    final client = _clients.firstWhere(
      (item) => _int(item['id']) == initialClientId,
      orElse: () => <String, dynamic>{},
    );
    if (client.isEmpty) return;
    final locations = _maps(client['locations']);
    if (locations.isEmpty) return;
    final location = locations.firstWhere(
      (item) => item['is_default'] == true,
      orElse: () => locations.first,
    );
    _stops.add(<String, dynamic>{
      'client_id': initialClientId,
      'location_id': _int(location['id']),
      'products': <String, int>{},
      'packages': <String, int>{},
      'package_components': <String, Map<String, int>>{},
      'sanitization_equipment': <String>[],
    });
    _initialProductsStopIndex = _stops.length - 1;
    _step = 1;
    _expandedStops.add(_stopKey(_stops.last));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Wpisz nazwę trasy.', error: true);
      setState(() => _step = 0);
      return;
    }
    if (_stops.isEmpty) {
      _message('Dodaj przynajmniej jeden punkt trasy.', error: true);
      setState(() => _step = 1);
      return;
    }
    final interval = int.tryParse(_interval.text);
    if (_recurring && (interval == null || interval < 1 || interval > 365)) {
      _message('Interwał trasy musi mieć od 1 do 365 dni.', error: true);
      setState(() => _step = 0);
      return;
    }
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .saveRoute(token, widget.id, {
            'name': _name.text.trim(),
            'scheduled_date': _isoDate(_date),
            'driver_id': _driverId == 0 ? null : _driverId,
            'region': _region.isEmpty ? null : _region,
            'status': _status,
            'notes': _notes.text.trim(),
            'is_recurring': _recurring,
            'recurrence_interval_days': _recurring ? interval : null,
            'stops': _stops,
          });
      ref.invalidate(adminRoutesProvider);
      if (!mounted) return;
      _dirty = false;
      _message('${response['message'] ?? 'Trasa została zapisana.'}');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _optimize() async {
    if (_stops.length < 2) return;
    setState(() => _optimizing = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final ordered = await ref
          .read(adminRepositoryProvider)
          .optimizeRoute(
            token,
            _stops
                .map(
                  (stop) => {
                    'client_id': stop['client_id'],
                    'location_id': stop['location_id'],
                  },
                )
                .toList(),
          );
      final byKey = {for (final stop in _stops) _stopKey(stop): stop};
      setState(() {
        _stops = ordered
            .map((stop) => byKey[_stopKey(stop)])
            .whereType<Map<String, dynamic>>()
            .toList();
        _dirty = true;
      });
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  Future<void> _addStops() async {
    final selected = await showModalBottomSheet<List<_LocationChoice>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LocationPicker(
        clients: _clients,
        existingKeys: _stops.map(_stopKey).toSet(),
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    _change(() {
      String? onlyAddedKey;
      for (final choice in selected) {
        final stop = choice.toStop();
        if (_stops.any((item) => _stopKey(item) == _stopKey(stop))) continue;
        _stops.add(stop);
        onlyAddedKey = _stopKey(stop);
      }
      if (selected.length == 1 && onlyAddedKey != null) {
        _expandedStops.add(onlyAddedKey);
      }
    });
  }

  void _reorderStops(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    _change(() {
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);
    });
  }

  void _removeStop(int index) {
    final removed = _stops[index];
    final removedKey = _stopKey(removed);
    _change(() {
      _stops.removeAt(index);
      _expandedStops.remove(removedKey);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Punkt został usunięty z trasy.'),
          action: SnackBarAction(
            label: 'Cofnij',
            onPressed: () {
              if (!mounted) return;
              _change(() {
                final restoreIndex = index > _stops.length
                    ? _stops.length
                    : index;
                _stops.insert(restoreIndex, removed);
                _expandedStops.add(removedKey);
              });
            },
          ),
        ),
      );
  }

  Future<void> _editProducts(int index) async {
    final client = _client(_stops[index]);
    if (client == null) return;
    final location = _location(_stops[index]);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductPicker(
        products: _products,
        visibleIds: _ints(
          location?['visible_product_ids'] ?? client['visible_product_ids'],
        ).toSet(),
        prices: _map(location?['prices'] ?? client['prices']),
        quantities: Map<String, int>.from(_intMap(_stops[index]['products'])),
        packages: _maps(location?['packages']),
        packageQuantities: Map<String, int>.from(
          _intMap(_stops[index]['packages']),
        ),
        packageComponentQuantities: _nestedIntMap(
          _stops[index]['package_components'],
        ),
      ),
    );
    if (result != null && mounted) {
      _change(() {
        _stops[index]['products'] = result['products'];
        _stops[index]['packages'] = result['packages'];
        _stops[index]['package_components'] = result['package_components'];
      });
    }
  }

  Future<void> _editSanitization(int index) async {
    final location = _location(_stops[index]);
    final sanitization = _map(location?['sanitization']);
    final dueDate = DateTime.tryParse(
      '${sanitization['sanitization_due_date'] ?? ''}',
    );
    final status = '${sanitization['sanitization_status'] ?? ''}';
    final dueForRoute =
        status == 'in_progress' ||
        status == 'overdue' ||
        sanitization['sanitization_is_overdue'] == true ||
        (dueDate != null && !dueDate.isAfter(_date));
    final allEquipment = _maps(sanitization['sanitization_equipment']);
    final taskEquipment = _maps(sanitization['sanitization_task_equipment']);
    final equipment = dueForRoute && taskEquipment.isNotEmpty
        ? taskEquipment
        : allEquipment;
    if (equipment.isEmpty) {
      _message(
        'Ta lokalizacja nie ma sprzętu wymagającego sanityzacji.',
        error: true,
      );
      return;
    }
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SanitizationEquipmentPicker(
        equipment: equipment,
        selected: _strings(_stops[index]['sanitization_equipment']),
        selectAllInitially: dueForRoute,
      ),
    );
    if (selected != null && mounted) {
      _change(() => _stops[index]['sanitization_equipment'] = selected);
    }
  }

  Map<String, dynamic>? _client(Map<String, dynamic> stop) {
    final id = _int(stop['client_id']);
    for (final client in _clients) {
      if (_int(client['id']) == id) return client;
    }
    return null;
  }

  Map<String, dynamic>? _location(Map<String, dynamic> stop) {
    final client = _client(stop);
    if (client == null) return null;
    final id = _int(stop['location_id']);
    for (final location in _maps(client['locations'])) {
      if (_int(location['id']) == id) return location;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty || _saving,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || !await _confirmDiscard()) return;
      if (!context.mounted) return;
      _dirty = false;
      Navigator.of(context).pop();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.id == null ? 'Nowa trasa' : 'Edytuj trasę'),
            if (!_loading)
              Text(
                '${_displayDate(_date)} · ${_stops.length} ${_pointWord(_stops.length)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WntColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _stepHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _step,
                    children: [_settingsPage(), _pointsPage()],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_loading) _editorActions(),
          adminBottomNavigation(context, ref, selectedIndex: 1),
        ],
      ),
    ),
  );

  Widget _stepHeader() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: WntColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _stepButton(
            index: 0,
            icon: Icons.tune_outlined,
            label: 'Ustawienia',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stepButton(
            index: 1,
            icon: Icons.route_outlined,
            label: 'Punkty (${_stops.length})',
          ),
        ),
      ],
    ),
  );

  Widget _stepButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _step == index;
    return Material(
      color: selected ? WntColors.brandSoft : WntColors.canvas,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _step = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? WntColors.brand : WntColors.muted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? WntColors.brand : WntColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsPage() => ListView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [
      _notice(
        icon: Icons.lightbulb_outline,
        title: 'Najpierw ustal dzień i kierowcę',
        text:
            'Potem dodasz wiele lokalizacji naraz i ustawisz ich kolejność na osobnym ekranie.',
      ),
      const SizedBox(height: 12),
      _sectionCard(
        title: 'Podstawowe informacje',
        icon: Icons.edit_calendar_outlined,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nazwa trasy',
              hintText: 'np. Tuszów',
            ),
          ),
          const SizedBox(height: 12),
          _fieldGrid([
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  initialDate: _date,
                );
                if (date != null) _change(() => _date = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Dzień realizacji',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _displayDate(_date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('driver-$_driverId'),
              initialValue: _driverId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kierowca'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Bez kierowcy')),
                ..._drivers.map(
                  (item) => DropdownMenuItem(
                    value: _int(item['id']),
                    child: Text(
                      '${item['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => _change(() => _driverId = value ?? 0),
            ),
          ]),
        ],
      ),
      const SizedBox(height: 12),
      _sectionCard(
        title: 'Powtarzanie',
        icon: Icons.event_repeat_outlined,
        children: [
          SwitchListTile.adaptive(
            value: _recurring,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Trasa cykliczna',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'System utworzy osobny szablon i kolejne wystąpienia.',
            ),
            onChanged: (value) => _change(() => _recurring = value),
          ),
          if (_recurring) ...[
            const SizedBox(height: 8),
            const Text(
              'Jak często?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const [7, 14, 28]) _intervalOption(option),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Własny interwał',
                suffixText: 'dni',
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.settings_outlined, color: WntColors.brand),
          title: const Text(
            'Dodatkowe ustawienia',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Region, status i uwagi do trasy'),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            _fieldGrid([
              DropdownButtonFormField<String>(
                key: ValueKey('region-$_region'),
                initialValue: _region,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Region'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Bez regionu')),
                  ..._regions.map(
                    (item) => DropdownMenuItem(
                      value: '${item['slug']}',
                      child: Text(
                        '${item['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => _change(() => _region = value ?? ''),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('status-$_status'),
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'planned',
                    child: Text('Zaplanowana'),
                  ),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('W realizacji'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Zakończona'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Anulowana'),
                  ),
                ],
                onChanged: (value) =>
                    _change(() => _status = value ?? 'planned'),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Uwagi do trasy',
                hintText: 'Informacja widoczna przy trasie',
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _pointsPage() {
    final query = _pointQuery.toLowerCase();
    final visibleIndexes = _stops
        .asMap()
        .entries
        .where((entry) {
          if (query.isEmpty) return true;
          final client = _client(entry.value);
          final location = _location(entry.value);
          return '${client?['name'] ?? ''} ${location?['name'] ?? ''} ${location?['address'] ?? ''}'
              .toLowerCase()
              .contains(query);
        })
        .map((entry) => entry.key)
        .toList();
    final canReorder = query.isEmpty;

    return Column(
      children: [
        _plannerToolbar(),
        Expanded(
          child: _stops.isEmpty
              ? _emptyRoute()
              : visibleIndexes.isEmpty
              ? const Center(
                  child: Text('Brak punktów pasujących do wyszukiwania.'),
                )
              : canReorder
              ? ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _stops.length,
                  onReorderItem: _reorderStops,
                  itemBuilder: (context, index) => _stopCard(
                    index,
                    key: ValueKey(_stopKey(_stops[index])),
                    reorderable: true,
                  ),
                )
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: visibleIndexes.length,
                  itemBuilder: (context, visibleIndex) {
                    final index = visibleIndexes[visibleIndex];
                    return _stopCard(
                      index,
                      key: ValueKey(_stopKey(_stops[index])),
                      reorderable: false,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _plannerToolbar() {
    final productQuantity = _stops.fold<int>(0, (sum, stop) {
      final products = _intMap(
        stop['products'],
      ).values.fold<int>(0, (value, item) => value + item);
      final packages = _intMap(
        stop['packages'],
      ).values.fold<int>(0, (value, item) => value + item);
      return sum + products + packages;
    });
    final sanitizations = _stops
        .where((stop) => _strings(stop['sanitization_equipment']).isNotEmpty)
        .length;
    if (MediaQuery.sizeOf(context).width < 430) {
      return _compactPlannerToolbar(productQuantity, sanitizations);
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan trasy',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Przeciągnij punkty, aby zmienić kolejność.',
                      style: TextStyle(color: WntColors.muted),
                    ),
                  ],
                ),
              ),
              _summaryValue('${_stops.length}', 'punkty'),
              const SizedBox(width: 12),
              _summaryValue('$productQuantity', 'do wydania'),
              if (sanitizations > 0) ...[
                const SizedBox(width: 12),
                _summaryValue('$sanitizations', 'sanityzacje'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _addStops,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Dodaj klientów'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stops.length > 1 && !_optimizing
                      ? _optimize
                      : null,
                  icon: _optimizing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.alt_route),
                  label: const Text('Optymalizuj'),
                ),
              ),
            ],
          ),
          if (_stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _pointSearch,
              decoration: InputDecoration(
                hintText: 'Szukaj na tej trasie',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _pointQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Wyczyść',
                        onPressed: _pointSearch.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compactPlannerToolbar(
    int productQuantity,
    int sanitizations,
  ) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_stops.length} ${_pointWord(_stops.length)} · $productQuantity do wydania'
                '${sanitizations > 0 ? ' · $sanitizations sanityz.' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WntColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _addStops,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
              label: const Text('Dodaj punkty'),
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              tooltip: 'Optymalizuj kolejność',
              onPressed: _stops.length > 1 && !_optimizing ? _optimize : null,
              icon: _optimizing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.alt_route),
            ),
          ],
        ),
        if (_stops.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _pointSearch,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Szukaj punktu na trasie',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _pointQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Wyczyść',
                      onPressed: _pointSearch.clear,
                      icon: const Icon(Icons.close, size: 20),
                    ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _summaryValue(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: WntColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(label, style: const TextStyle(color: WntColors.muted, fontSize: 11)),
    ],
  );

  Widget _emptyRoute() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: WntColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_location_alt_outlined,
              size: 34,
              color: WntColors.brand,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dodaj pierwsze punkty',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Wyszukaj klientów, zaznacz kilka lokalizacji i dodaj je do trasy jedną operacją.',
            textAlign: TextAlign.center,
            style: TextStyle(color: WntColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _addStops,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Wybierz klientów'),
          ),
        ],
      ),
    ),
  );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: WntColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  Widget _intervalOption(int days) {
    final selected = int.tryParse(_interval.text) == days;
    return OutlinedButton(
      onPressed: () => setState(() {
        _dirty = true;
        _interval.text = '$days';
      }),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? WntColors.brand : WntColors.text,
        backgroundColor: selected ? WntColors.brandSoft : Colors.white,
        side: BorderSide(color: selected ? WntColors.brand : WntColors.line),
      ),
      child: Text(_intervalLabel(days)),
    );
  }

  Widget _fieldGrid(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 680) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              Expanded(child: fields[index]),
              if (index < fields.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      }
      return Column(
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            fields[index],
            if (index < fields.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    },
  );

  Widget _notice({
    required IconData icon,
    required String title,
    required String text,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: WntColors.brandSoft,
      border: Border.all(color: WntColors.brand.withValues(alpha: .22)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: WntColors.brand),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: WntColors.text)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _editorActions() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: WntColors.line)),
    ),
    child: _step == 0
        ? SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                if (_name.text.trim().isEmpty) {
                  _message('Wpisz nazwę trasy.', error: true);
                  return;
                }
                setState(() => _step = 1);
              },
              icon: const Icon(Icons.arrow_forward),
              label: Text('Dalej: punkty (${_stops.length})'),
            ),
          )
        : Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _step = 0),
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Ustawienia'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text('Zapisz trasę · ${_stops.length} pkt'),
                ),
              ),
            ],
          ),
  );

  Future<bool> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odrzucić zmiany?'),
        content: const Text(
          'Niezapisane ustawienia i kolejność punktów zostaną utracone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zostań'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Odrzuć'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _stopCard(int index, {required Key key, required bool reorderable}) {
    final stop = _stops[index];
    final stopKey = _stopKey(stop);
    final client = _client(stop) ?? const <String, dynamic>{};
    final locations = _maps(client['locations']);
    final location = _location(stop);
    final quantities = _intMap(stop['products']);
    final packageQuantities = _intMap(stop['packages']);
    final count = [
      ...quantities.values,
      ...packageQuantities.values,
    ].fold<int>(0, (sum, value) => sum + value);
    final sanitization = _map(location?['sanitization']);
    final sanitizationEquipment = _maps(sanitization['sanitization_equipment']);
    final selectedSanitizationEquipment = _strings(
      stop['sanitization_equipment'],
    );
    final sanitationStatus = '${sanitization['sanitization_status'] ?? ''}';
    final sanitationDueDate = DateTime.tryParse(
      '${sanitization['sanitization_due_date'] ?? ''}',
    );
    final sanitationUrgent =
        sanitationStatus == 'in_progress' ||
        sanitationStatus == 'overdue' ||
        sanitization['sanitization_is_overdue'] == true ||
        (sanitationDueDate != null && !sanitationDueDate.isAfter(_date));
    final sanitationSelected = selectedSanitizationEquipment.isNotEmpty;
    final sanitationLabel = sanitationSelected
        ? 'Sanityzacja do wykonania: ${selectedSanitizationEquipment.length} szt.'
        : sanitationStatus == 'in_progress'
        ? 'Sanityzacja do dokończenia'
        : sanitationUrgent
        ? 'Zaległa sanityzacja'
        : 'Sanityzacja na żądanie';
    final expanded = _expandedStops.contains(stopKey);
    final productLines = quantities.values.where((value) => value > 0).length;
    final packageLines = packageQuantities.values
        .where((value) => value > 0)
        .length;
    final productQuantity = [
      ...quantities.values,
      ...packageQuantities.values,
    ].fold<int>(0, (sum, value) => sum + value);
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              expanded
                  ? _expandedStops.remove(stopKey)
                  : _expandedStops.add(stopKey);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: true,
                    onChanged: (selected) {
                      if (selected == false) _removeStop(index);
                    },
                    semanticLabel: 'Odznacz, aby usunąć klienta z trasy',
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: WntColors.brandSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: WntColors.brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${client['name'] ?? 'Klient'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WntColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${location?['name'] ?? 'Lokalizacja'} · ${location?['address'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: WntColors.muted),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _infoChip(
                              icon: Icons.inventory_2_outlined,
                              text: productQuantity > 0
                                  ? '$productQuantity szt. · ${productLines + packageLines} poz.'
                                  : 'Bez produktów',
                              active: productQuantity > 0,
                            ),
                            if (sanitationSelected || sanitationUrgent)
                              _infoChip(
                                icon: Icons.cleaning_services_outlined,
                                text: sanitationSelected
                                    ? '${selectedSanitizationEquipment.length} sanityz.'
                                    : 'Sanityzacja zaległa',
                                error: sanitationUrgent,
                                active: sanitationSelected,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (reorderable)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.drag_handle, color: WntColors.muted),
                      ),
                    ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: WntColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (locations.length > 1) ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey('location-$stopKey'),
                      initialValue: _int(stop['location_id']),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Lokalizacja klienta',
                      ),
                      items: locations
                          .map(
                            (item) => DropdownMenuItem(
                              value: _int(item['id']),
                              child: Text(
                                '${item['name']} · ${item['address'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => _changeStopLocation(index, value),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _editProducts(index),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          count > 0 ? 'Wydanie · $count' : 'Ustaw wydanie',
                        ),
                      ),
                      if (sanitizationEquipment.isNotEmpty)
                        sanitationUrgent || sanitationSelected
                            ? FilledButton.icon(
                                onPressed: () => _editSanitization(index),
                                style: FilledButton.styleFrom(
                                  backgroundColor: WntColors.error,
                                ),
                                icon: const Icon(
                                  Icons.cleaning_services_outlined,
                                ),
                                label: Text(sanitationLabel),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => _editSanitization(index),
                                icon: const Icon(
                                  Icons.cleaning_services_outlined,
                                ),
                                label: Text(sanitationLabel),
                              ),
                      TextButton.icon(
                        onPressed: () => _removeStop(index),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Usuń punkt'),
                        style: TextButton.styleFrom(
                          foregroundColor: WntColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String text,
    bool active = false,
    bool error = false,
  }) {
    final color = error
        ? WntColors.error
        : active
        ? WntColors.brand
        : WntColors.muted;
    final background = error
        ? WntColors.errorSoft
        : active
        ? WntColors.brandSoft
        : WntColors.canvas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeStopLocation(int index, int? value) {
    if (value == null || value == _int(_stops[index]['location_id'])) return;
    final stop = _stops[index];
    final nextKey = '${_int(stop['client_id'])}:$value';
    if (_stops.asMap().entries.any(
      (entry) => entry.key != index && _stopKey(entry.value) == nextKey,
    )) {
      _message('Ta lokalizacja jest już na trasie.', error: true);
      return;
    }
    final oldKey = _stopKey(stop);
    _change(() {
      stop['location_id'] = value;
      stop['products'] = <String, int>{};
      stop['packages'] = <String, int>{};
      stop['package_components'] = <String, Map<String, int>>{};
      stop['sanitization_equipment'] = <String>[];
      _expandedStops.remove(oldKey);
      _expandedStops.add(nextKey);
    });
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? WntColors.error : null,
      ),
    );
  }
}

class _SanitizationEquipmentPicker extends StatefulWidget {
  const _SanitizationEquipmentPicker({
    required this.equipment,
    required this.selected,
    required this.selectAllInitially,
  });

  final List<Map<String, dynamic>> equipment;
  final List<String> selected;
  final bool selectAllInitially;

  @override
  State<_SanitizationEquipmentPicker> createState() =>
      _SanitizationEquipmentPickerState();
}

class _SanitizationEquipmentPickerState
    extends State<_SanitizationEquipmentPicker> {
  late final Set<String> selected;

  @override
  void initState() {
    super.initState();
    final allowed = widget.equipment
        .where((item) => item['selectable'] != false)
        .map((item) => '${item['key']}')
        .where((key) => key.isNotEmpty)
        .toSet();
    selected = widget.selected.where(allowed.contains).toSet();
    if (selected.isEmpty && widget.selectAllInitially) {
      selected.addAll(allowed);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sanityzacje na trasie',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Wybierz konkretne urządzenia, które kierowca ma poddać sanityzacji.',
                      style: TextStyle(color: WntColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Zamknij',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.equipment.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = widget.equipment[index];
              final key = '${item['key']}';
              final selectable = item['selectable'] != false;
              final completed =
                  item['completed'] == true ||
                  '${item['selection_state']}' == 'completed';
              return Material(
                color: selectable ? Colors.white : WntColors.canvas,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: WntColors.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: CheckboxListTile(
                  value: selected.contains(key),
                  onChanged: selectable
                      ? (checked) => setState(() {
                          if (checked == true) {
                            selected.add(key);
                          } else {
                            selected.remove(key);
                          }
                        })
                      : null,
                  title: Text(
                    '${item['label'] ?? item['equipment_name'] ?? 'Urządzenie'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selectable ? null : WntColors.muted,
                    ),
                  ),
                  subtitle: !selectable
                      ? Text(completed ? 'Wykonana' : 'Poza tym zadaniem')
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: WntColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <String>[]),
                    child: const Text('Usuń z trasy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            selected.toList(growable: false),
                          ),
                    child: Text('Zapisz (${selected.length})'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LocationChoice {
  const _LocationChoice({required this.client, required this.location});

  final Map<String, dynamic> client;
  final Map<String, dynamic> location;

  String get key => '${_int(client['id'])}:${_int(location['id'])}';

  Map<String, dynamic> toStop() => <String, dynamic>{
    'client_id': _int(client['id']),
    'location_id': _int(location['id']),
    'products': <String, int>{},
    'packages': <String, int>{},
    'package_components': <String, Map<String, int>>{},
    'sanitization_equipment': <String>[],
  };
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({required this.clients, required this.existingKeys});

  final List<Map<String, dynamic>> clients;
  final Set<String> existingKeys;

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final Set<String> selected = <String>{};
  String query = '';
  String region = '';

  late final List<_LocationChoice> choices = [
    for (final client in widget.clients)
      for (final location in _maps(client['locations']))
        _LocationChoice(client: client, location: location),
  ];

  List<String> get regions =>
      choices
          .map((item) => '${item.location['region'] ?? ''}'.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<_LocationChoice> get visibleChoices {
    final normalizedQuery = query.trim().toLowerCase();
    return choices.where((choice) {
      final locationRegion = '${choice.location['region'] ?? ''}'.trim();
      if (region.isNotEmpty && locationRegion != region) return false;
      if (normalizedQuery.isEmpty) return true;
      final searchable = [
        choice.client['name'],
        choice.location['name'],
        choice.location['address'],
        choice.location['city'],
        locationRegion,
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleChoices;
    final availableVisible = visible
        .where((choice) => !widget.existingKeys.contains(choice.key))
        .toList();
    final allVisibleSelected =
        availableVisible.isNotEmpty &&
        availableVisible.every((choice) => selected.contains(choice.key));

    return FractionallySizedBox(
      heightFactor: .94,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dodaj punkty do trasy',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Możesz zaznaczyć kilku klientów i kilka lokalizacji naraz.',
                        style: TextStyle(color: WntColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Szukaj klienta, lokalizacji lub adresu',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (regions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: region,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Region'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Wszystkie regiony'),
                      ),
                      ...regions.map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => region = value ?? ''),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${visible.length} ${_pointWord(visible.length)}',
                        style: const TextStyle(
                          color: WntColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: availableVisible.isEmpty
                          ? null
                          : () => setState(() {
                              if (allVisibleSelected) {
                                selected.removeAll(
                                  availableVisible.map((item) => item.key),
                                );
                              } else {
                                selected.addAll(
                                  availableVisible.map((item) => item.key),
                                );
                              }
                            }),
                      child: Text(
                        allVisibleSelected
                            ? 'Odznacz widoczne'
                            : 'Zaznacz widoczne',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('Brak pasujących lokalizacji.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final choice = visible[index];
                      final alreadyAdded = widget.existingKeys.contains(
                        choice.key,
                      );
                      final checked =
                          alreadyAdded || selected.contains(choice.key);
                      final locationName = '${choice.location['name'] ?? ''}'
                          .trim();
                      final address = '${choice.location['address'] ?? ''}'
                          .trim();
                      return Material(
                        color: alreadyAdded ? WntColors.canvas : Colors.white,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: WntColors.line),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CheckboxListTile(
                          value: checked,
                          onChanged: alreadyAdded
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    selected.add(choice.key);
                                  } else {
                                    selected.remove(choice.key);
                                  }
                                }),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            '${choice.client['name'] ?? 'Klient'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (locationName.isNotEmpty) locationName,
                              if (address.isNotEmpty) address,
                              if (alreadyAdded) 'Już na trasie',
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: WntColors.line)),
              ),
              child: Row(
                children: [
                  if (selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(selected.clear),
                      child: const Text('Wyczyść'),
                    ),
                  if (selected.isNotEmpty) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              choices
                                  .where((item) => selected.contains(item.key))
                                  .toList(growable: false),
                            ),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: Text('Dodaj ${selected.length}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({
    required this.products,
    required this.visibleIds,
    required this.prices,
    required this.quantities,
    required this.packages,
    required this.packageQuantities,
    required this.packageComponentQuantities,
  });
  final List<Map<String, dynamic>> products;
  final Set<int> visibleIds;
  final Map<String, dynamic> prices;
  final Map<String, int> quantities;
  final List<Map<String, dynamic>> packages;
  final Map<String, int> packageQuantities;
  final Map<String, Map<String, int>> packageComponentQuantities;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  late Map<String, int> quantities = Map<String, int>.from(widget.quantities);
  late Map<String, int> packageQuantities = Map<String, int>.from(
    widget.packageQuantities,
  );
  late Map<String, Map<String, int>> packageComponentQuantities = {
    for (final entry in widget.packageComponentQuantities.entries)
      entry.key: Map<String, int>.from(entry.value),
  };
  String query = '';
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final matching = widget.products
        .where(
          (product) =>
              '${product['name']}'.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    bool isAssigned(Map<String, dynamic> product) =>
        widget.visibleIds.contains(_int(product['id'])) ||
        (quantities['${product['id']}'] ?? 0) > 0;
    final assigned = matching.where(isAssigned).toList();
    final remaining = matching
        .where((product) => !isAssigned(product))
        .toList();
    final products = query.isNotEmpty || showAll
        ? [...assigned, ...remaining]
        : widget.visibleIds.isEmpty
        ? matching
        : assigned;
    final canShowMore =
        query.isEmpty &&
        !showAll &&
        widget.visibleIds.isNotEmpty &&
        remaining.isNotEmpty;
    return FractionallySizedBox(
      heightFactor: .92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Produkty dla punktu',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                labelText: 'Szukaj produktu',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount:
                  widget.packages.length +
                  products.length +
                  (canShowMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index < widget.packages.length) {
                  final package = widget.packages[index];
                  final id = '${package['id']}';
                  final quantity = packageQuantities[id] ?? 0;
                  final components = _maps(package['components']);
                  final selected = packageComponentQuantities.putIfAbsent(
                    id,
                    () => <String, int>{},
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: quantity > 0
                            ? WntColors.brandSoft
                            : Colors.white,
                        border: Border.all(
                          color: quantity > 0
                              ? WntColors.brand
                              : WntColors.line,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.inventory_2_outlined),
                            title: Text('${package['name']}'),
                            subtitle: Text('${package['price']} zł za pakiet'),
                            value: quantity > 0,
                            onChanged: (enabled) => setState(() {
                              if (!enabled) {
                                packageQuantities.remove(id);
                                selected.clear();
                                return;
                              }
                              packageQuantities[id] = 1;
                              for (final component in components) {
                                selected['${component['product_id']}'] =
                                    _bool(component['is_rental'])
                                    ? (_bool(component['issue_default'])
                                          ? 1
                                          : 0)
                                    : _int(component['quantity']);
                              }
                            }),
                          ),
                          if (quantity > 0) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Faktycznie do wydania',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (
                                    var componentIndex = 0;
                                    componentIndex < components.length;
                                    componentIndex++
                                  ) ...[
                                    Builder(
                                      builder: (context) {
                                        final component =
                                            components[componentIndex];
                                        final productId =
                                            '${component['product_id']}';
                                        final included = _int(
                                          component['quantity'],
                                        );
                                        final isRental = _bool(
                                          component['is_rental'],
                                        );
                                        final alreadyAtLocation = _int(
                                          component['existing_quantity'],
                                        );
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('${component['name']}'),
                                                  Text(
                                                    isRental
                                                        ? alreadyAtLocation > 0
                                                              ? 'Pakiet korzysta ze sprzętu już będącego w tej lokalizacji.'
                                                              : 'Brak sprzętu w lokalizacji — wydanie zaznaczone automatycznie.'
                                                        : 'Pakiet obejmuje do $included szt.',
                                                    style: const TextStyle(
                                                      color: WntColors.muted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isRental)
                                              Checkbox(
                                                value:
                                                    (selected[productId] ??
                                                        (_bool(
                                                              component['issue_default'],
                                                            )
                                                            ? 1
                                                            : 0)) >
                                                    0,
                                                onChanged: (value) =>
                                                    setState(() {
                                                      selected[productId] =
                                                          value == true ? 1 : 0;
                                                    }),
                                                semanticLabel: 'Wydaj sprzęt',
                                              )
                                            else
                                              _Counter(
                                                value:
                                                    selected[productId] ??
                                                    included,
                                                onChanged: (value) => setState(
                                                  () {
                                                    selected[productId] = value
                                                        .clamp(0, included);
                                                  },
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                    if (componentIndex < components.length - 1)
                                      const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                final productIndex = index - widget.packages.length;
                if (canShowMore && productIndex == products.length) {
                  return TextButton.icon(
                    onPressed: () => setState(() => showAll = true),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Pokaż wszystkie produkty'),
                  );
                }
                final product = products[productIndex];
                final id = '${product['id']}';
                final quantity = quantities[id] ?? 0;
                final price = widget.prices[id] ?? product['default_price'];
                return ListTile(
                  title: Text('${product['name']}'),
                  subtitle: Text('$price zł / ${product['unit'] ?? 'szt'}'),
                  trailing: _Counter(
                    value: quantity,
                    onChanged: (value) => setState(() {
                      if (value == 0) {
                        quantities.remove(id);
                      } else {
                        quantities[id] = value;
                      }
                    }),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'products': quantities,
                    'packages': packageQuantities,
                    'package_components': packageComponentQuantities,
                  }),
                  child: const Text('Dodaj produkty'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: WntColors.line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 40),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 40),
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

List<Map<String, dynamic>> _maps(dynamic value) {
  final items = value is List
      ? value
      : value is Map
      ? value.values.toList()
      : const <dynamic>[];
  return items
      .whereType<Map>()
      .map(
        (item) => <String, dynamic>{
          for (final entry in item.entries) '${entry.key}': entry.value,
        },
      )
      .toList();
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? <String, dynamic>{
        for (final entry in value.entries) '${entry.key}': entry.value,
      }
    : <String, dynamic>{};
Map<String, int> _intMap(dynamic value) => value is Map
    ? value.map((key, value) => MapEntry('$key', _int(value)))
    : {};
Map<String, Map<String, int>> _nestedIntMap(dynamic value) => value is Map
    ? value.map((key, nested) => MapEntry('$key', _intMap(nested)))
    : {};
List<int> _ints(dynamic value) =>
    value is List ? value.map(_int).where((id) => id > 0).toList() : [];
List<String> _strings(dynamic value) => value is List
    ? value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList()
    : [];
int _int(dynamic value) => int.tryParse('$value') ?? 0;
bool _bool(dynamic value) => value == true || value == 1 || value == '1';
int _locationId(Map<String, dynamic> stop) =>
    _int(stop['location_id'] ?? stop['client_location_id']);
String _stopKey(Map<String, dynamic> stop) =>
    '${_int(stop['client_id'])}:${_locationId(stop)}';
DateTime _parseDate(String value) {
  final parts = value.split('.');
  if (parts.length == 3) {
    return DateTime(
      int.tryParse(parts[2]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[0]) ?? DateTime.now().day,
    );
  }
  return DateTime.tryParse(value) ?? DateTime.now();
}

String _two(int value) => value.toString().padLeft(2, '0');
String _displayDate(DateTime date) =>
    '${_two(date.day)}.${_two(date.month)}.${date.year}';
String _isoDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';
String _pointWord(int count) {
  if (count == 1) return 'punkt';
  final lastTwo = count % 100;
  final last = count % 10;
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return 'punkty';
  }
  return 'punktów';
}

String _intervalLabel(int days) => switch (days) {
  7 => 'Co tydzień',
  14 => 'Co 2 tygodnie',
  28 => 'Co 4 tygodnie',
  _ => 'Co $days dni',
};
