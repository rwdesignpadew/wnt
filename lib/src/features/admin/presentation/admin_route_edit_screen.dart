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
  int? _initialProductsStopIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _interval.dispose();
    super.dispose();
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
        _name.text = 'Nowa trasa';
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
              },
            )
            .toList();
      }
      _prepareInitialClient();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
    });
    _initialProductsStopIndex = _stops.length - 1;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Wpisz nazwę trasy.', error: true);
      return;
    }
    if (_stops.isEmpty) {
      _message('Dodaj przynajmniej jeden punkt trasy.', error: true);
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
            'recurrence_interval_days': _recurring
                ? (int.tryParse(_interval.text) ?? 14)
                : null,
            'stops': _stops,
          });
      ref.invalidate(adminRoutesProvider);
      if (!mounted) return;
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
      });
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  Future<void> _addStop() async {
    final client = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ClientPicker(clients: _clients),
    );
    if (client == null || !mounted) return;
    final locations = _maps(client['locations']);
    if (locations.isEmpty) {
      _message('Ten klient nie ma aktywnej lokalizacji.', error: true);
      return;
    }
    final location = locations.firstWhere(
      (item) => item['is_default'] == true,
      orElse: () => locations.first,
    );
    final stop = <String, dynamic>{
      'client_id': _int(client['id']),
      'location_id': _int(location['id']),
      'products': <String, int>{},
      'packages': <String, int>{},
    };
    if (_stops.any((item) => _stopKey(item) == _stopKey(stop))) {
      _message('Ta lokalizacja jest już na trasie.', error: true);
      return;
    }
    setState(() => _stops.add(stop));
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
        visibleIds: _ints(client['visible_product_ids']).toSet(),
        prices: _map(client['prices']),
        quantities: Map<String, int>.from(_intMap(_stops[index]['products'])),
        packages: _maps(location?['packages']),
        packageQuantities: Map<String, int>.from(
          _intMap(_stops[index]['packages']),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _stops[index]['products'] = result['products'];
        _stops[index]['packages'] = result['packages'];
      });
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.id == null ? 'Nowa trasa' : 'Edytuj trasę'),
    ),
    bottomNavigationBar: adminBottomNavigation(context, ref),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _routeForm()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Kolejność trasy',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Optymalizuj Google',
                              onPressed: _stops.length > 1 && !_optimizing
                                  ? _optimize
                                  : null,
                              icon: _optimizing
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.alt_route),
                            ),
                            FilledButton.icon(
                              onPressed: _addStop,
                              icon: const Icon(Icons.add),
                              label: const Text('Dodaj punkt'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverReorderableList(
                        itemCount: _stops.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final stop = _stops.removeAt(oldIndex);
                            _stops.insert(newIndex, stop);
                          });
                        },
                        itemBuilder: (context, index) => _stopCard(index),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: WntColors.line)),
                  ),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Zapisz trasę'),
                  ),
                ),
              ),
            ],
          ),
  );

  Widget _routeForm() => Padding(
    padding: const EdgeInsets.all(16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nazwa trasy'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        initialDate: _date,
                      );
                      if (date != null) setState(() => _date = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_displayDate(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CheckboxListTile(
                    value: _recurring,
                    onChanged: (value) =>
                        setState(() => _recurring = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Trasa cykliczna'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
            if (_recurring) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Powtarzaj co ile dni',
                  suffixText: 'dni',
                ),
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _driverId,
              decoration: const InputDecoration(labelText: 'Kierowca'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Bez kierowcy')),
                ..._drivers.map(
                  (item) => DropdownMenuItem(
                    value: _int(item['id']),
                    child: Text('${item['name']}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _driverId = value ?? 0),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _region,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Region'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Bez regionu'),
                      ),
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
                    onChanged: (value) => setState(() => _region = value ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                        setState(() => _status = value ?? 'planned'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Uwagi'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stopCard(int index) {
    final stop = _stops[index];
    final client = _client(stop) ?? const <String, dynamic>{};
    final locations = _maps(client['locations']);
    final location = _location(stop);
    final quantities = _intMap(stop['products']);
    final packageQuantities = _intMap(stop['packages']);
    final count = [
      ...quantities.values,
      ...packageQuantities.values,
    ].fold<int>(0, (sum, value) => sum + value);
    return Card(
      key: ValueKey('${_stopKey(stop)}-$index'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle, color: WntColors.muted),
                  ),
                ),
                CircleAvatar(radius: 18, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${client['name'] ?? 'Klient'} - ${location?['name'] ?? 'Lokalizacja'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${location?['address'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: WntColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Usuń punkt',
                  onPressed: () => setState(() => _stops.removeAt(index)),
                  icon: const Icon(Icons.close, color: WntColors.error),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _int(stop['location_id']),
                    decoration: const InputDecoration(labelText: 'Lokalizacja'),
                    items: locations
                        .map(
                          (item) => DropdownMenuItem(
                            value: _int(item['id']),
                            child: Text(
                              '${item['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => stop['location_id'] = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Produkty',
                  onPressed: () => _editProducts(index),
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.add_shopping_cart_outlined),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _ClientPicker extends StatefulWidget {
  const _ClientPicker({required this.clients});
  final List<Map<String, dynamic>> clients;

  @override
  State<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends State<_ClientPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.clients.where((client) {
      final value = '$client'.toLowerCase();
      return value.contains(query.toLowerCase());
    }).toList();
    return FractionallySizedBox(
      heightFactor: .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                labelText: 'Szukaj klienta lub adresu',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final client = filtered[index];
                final location = _maps(client['locations']).firstOrNull;
                return ListTile(
                  title: Text('${client['name']}'),
                  subtitle: Text('${location?['address'] ?? ''}'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.pop(context, client),
                );
              },
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
  });
  final List<Map<String, dynamic>> products;
  final Set<int> visibleIds;
  final Map<String, dynamic> prices;
  final Map<String, int> quantities;
  final List<Map<String, dynamic>> packages;
  final Map<String, int> packageQuantities;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  late Map<String, int> quantities = Map<String, int>.from(widget.quantities);
  late Map<String, int> packageQuantities = Map<String, int>.from(
    widget.packageQuantities,
  );
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
                  final components = _maps(package['components'])
                      .map(
                        (item) => '${item['name']} x ${_int(item['quantity'])}',
                      )
                      .join(', ');
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text('${package['name']}'),
                    subtitle: Text(
                      '${package['price']} zł${components.isEmpty ? '' : ' - $components'}',
                    ),
                    trailing: _Counter(
                      value: quantity,
                      onChanged: (value) => setState(() {
                        if (value == 0) {
                          packageQuantities.remove(id);
                        } else {
                          packageQuantities[id] = value;
                        }
                      }),
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
List<int> _ints(dynamic value) =>
    value is List ? value.map(_int).where((id) => id > 0).toList() : [];
int _int(dynamic value) => int.tryParse('$value') ?? 0;
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
