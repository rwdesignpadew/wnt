import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_bottom_navigation.dart';

class AdminBalancesScreen extends ConsumerStatefulWidget {
  const AdminBalancesScreen({super.key});

  @override
  ConsumerState<AdminBalancesScreen> createState() =>
      _AdminBalancesScreenState();
}

class _AdminBalancesScreenState extends ConsumerState<AdminBalancesScreen> {
  String _filter = 'debt';
  String _search = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Salda klientów')),
    bottomNavigationBar: adminBottomNavigation(context, ref),
    body: ref
        .watch(adminBalancesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _Error('$e', () => ref.invalidate(adminBalancesProvider)),
          data: (data) {
            final items = _maps(data['items']);
            final query = _search.trim().toLowerCase();
            final visible = items.where((item) {
              final matchesTab = switch (_filter) {
                'debt' => _double(item['total_debt']) > .005,
                'credit' => _double(item['overpayment']) > .005,
                _ => true,
              };
              if (!matchesTab) return false;
              if (query.isEmpty) return true;
              return '${item['name']} ${item['nip']}'.toLowerCase().contains(
                query,
              );
            }).toList();
            final debtCount = items
                .where((item) => _double(item['total_debt']) > .005)
                .length;
            final creditCount = items
                .where((item) => _double(item['overpayment']) > .005)
                .length;
            return RefreshIndicator(
              onRefresh: () => ref.refresh(adminBalancesProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _ManagementTabs(
                    selected: _filter,
                    tabs: [
                      ('debt', 'Zaległości', debtCount),
                      ('credit', 'Nadpłaty', creditCount),
                      ('all', 'Wszyscy', items.length),
                    ],
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Szukaj po nazwie lub NIP',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    const _EmptyMessage('Brak klientów spełniających kryteria.')
                  else
                    for (final item in visible)
                      Card(
                        child: ListTile(
                          title: Text('${item['name'] ?? ''}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ('${item['nip'] ?? ''}'.trim().isNotEmpty)
                                Text('NIP: ${item['nip']}'),
                              Text(
                                'Z WZ: ${_money(item['document_debt'])}  •  ręczna: ${_money(item['manual_debt'])}',
                              ),
                              Text(
                                'Razem zaległość: ${_money(item['total_debt'])}  •  nadpłata: ${_money(item['overpayment'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => _editBalance(context, item),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
  );

  Future<void> _editBalance(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    var type = 'credit';
    final amount = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Saldo - ${item['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'credit', child: Text('Nadpłata')),
                  DropdownMenuItem(value: 'debt', child: Text('Zaległość')),
                  DropdownMenuItem(value: 'zero', child: Text('Wyzeruj saldo')),
                  DropdownMenuItem(
                    value: 'document_debt_decrease',
                    child: Text('Zmniejsz zaległość z WZ'),
                  ),
                ],
                onChanged: (v) => setState(() => type = v!),
                decoration: const InputDecoration(labelText: 'Rodzaj'),
              ),
              if (type != 'zero')
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Kwota'),
                ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Powód'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateBalance(
            ref.read(authControllerProvider).session!.token,
            int.parse('${item['id']}'),
            type,
            double.tryParse(amount.text.replaceAll(',', '.')) ?? 0,
            reason.text,
          );
      ref.invalidate(adminBalancesProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      amount.dispose();
      reason.dispose();
    }
  }
}

class AdminRentalsScreen extends ConsumerStatefulWidget {
  const AdminRentalsScreen({super.key});

  @override
  ConsumerState<AdminRentalsScreen> createState() => _AdminRentalsScreenState();
}

class _AdminRentalsScreenState extends ConsumerState<AdminRentalsScreen> {
  String _tab = 'active';

  Future<void> _addRental(Map<String, dynamic> data) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RentalEditorSheet(data: data),
    );
    if (saved == true) {
      ref.invalidate(adminRentalsProvider);
      ref.invalidate(adminRoutesProvider);
    }
  }

  Future<void> _returnRental(Map<String, dynamic> item) async {
    final quantity = TextEditingController(text: '${item['quantity'] ?? 1}');
    final description = TextEditingController();
    var damaged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Zwróć / zakończ dzierżawę'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${item['client_name']} - ${item['product_name']}'),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Zwracana ilość (maks. ${item['quantity']})',
                  ),
                ),
                CheckboxListTile(
                  value: damaged,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sprzęt uszkodzony'),
                  onChanged: (value) =>
                      setDialogState(() => damaged = value ?? false),
                ),
                if (damaged)
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Opis uszkodzenia',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(quantity.text) ?? 0;
                if (value < 1 ||
                    value > _int(item['quantity']) ||
                    (damaged && description.text.trim().isEmpty)) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Przyjmij i utwórz PZ'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      quantity.dispose();
      description.dispose();
      return;
    }
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .returnClientRental(
            ref.read(authControllerProvider).session!.token,
            _int(item['client_id']),
            _int(item['id']),
            quantity: int.parse(quantity.text),
            damaged: damaged,
            damageDescription: description.text.trim(),
          );
      ref.invalidate(adminRentalsProvider);
      if (mounted) {
        _snack(context, '${response['message'] ?? 'Zwrot zapisany.'}');
      }
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    } finally {
      quantity.dispose();
      description.dispose();
    }
  }

  Future<void> _deletePending(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anulować dzierżawę?'),
        content: const Text(
          'Oczekująca dzierżawa zostanie usunięta także z trasy. Aktywne dzierżawy klienta pozostaną bez zmian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Nie'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Anuluj dzierżawę'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .deletePendingRental(
            ref.read(authControllerProvider).session!.token,
            _int(item['id']),
          );
      ref.invalidate(adminRentalsProvider);
      ref.invalidate(adminRoutesProvider);
      if (mounted) {
        _snack(context, '${response['message'] ?? 'Dzierżawa anulowana.'}');
      }
    } catch (error) {
      if (mounted) _snack(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dzierżawy')),
    bottomNavigationBar: adminBottomNavigation(context, ref),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final data = await ref.read(adminRentalsProvider.future);
        if (mounted) await _addRental(data);
      },
      icon: const Icon(Icons.add),
      label: const Text('Nowa dzierżawa'),
    ),
    body: ref
        .watch(adminRentalsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _Error('$e', () => ref.invalidate(adminRentalsProvider)),
          data: (data) {
            final pending = _maps(data['pending']);
            final active = _maps(data['active']);
            final items = _tab == 'pending' ? pending : active;
            return RefreshIndicator(
              onRefresh: () => ref.refresh(adminRentalsProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  _ManagementTabs(
                    selected: _tab,
                    tabs: [
                      ('active', 'Aktywne', active.length),
                      ('pending', 'W realizacji', pending.length),
                    ],
                    onChanged: (value) => setState(() => _tab = value),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    _EmptyMessage(
                      _tab == 'pending'
                          ? 'Brak dzierżaw oczekujących na wydanie.'
                          : 'Brak aktywnych dzierżaw.',
                    )
                  else
                    for (final item in items)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            _tab == 'pending'
                                ? Icons.schedule
                                : Icons.water_drop_outlined,
                          ),
                          title: Text(
                            '${item['client_name']} - ${item['location_name'] ?? 'Główna lokalizacja'}',
                          ),
                          subtitle: Text(
                            '${item['product_name']} • ${item['quantity']} szt.'
                            '${_tab == 'pending' ? '\n${item['date'] ?? ''} - ${item['route_name'] ?? 'bez trasy'}${item['initial_fee_collected'] == true ? ' • opłata za ten miesiąc na WZ' : ' • opłata od faktury miesięcznej'}' : '\n${item['recurring_billing'] == true ? 'Rozliczenie miesięczne' : 'Stare ustawienie jednorazowe'} • ${_money(item['unit_price'])} netto / szt.'}',
                          ),
                          isThreeLine: true,
                          trailing: _tab == 'pending'
                              ? IconButton(
                                  tooltip: 'Anuluj oczekującą dzierżawę',
                                  onPressed: () => _deletePending(item),
                                  icon: const Icon(Icons.delete_outline),
                                )
                              : FilledButton.tonal(
                                  onPressed: () => _returnRental(item),
                                  child: const Text('Zwróć'),
                                ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
  );
}

class _RentalEditorSheet extends ConsumerStatefulWidget {
  const _RentalEditorSheet({required this.data});

  final Map<String, dynamic> data;

  @override
  ConsumerState<_RentalEditorSheet> createState() => _RentalEditorSheetState();
}

class _RentalEditorSheetState extends ConsumerState<_RentalEditorSheet> {
  late final List<Map<String, dynamic>> clients = _maps(widget.data['clients']);
  late final List<Map<String, dynamic>> products = _maps(
    widget.data['products'],
  );
  late final List<Map<String, dynamic>> routes = _maps(widget.data['routes']);
  late final List<Map<String, dynamic>> drivers = _maps(widget.data['drivers']);
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController(text: '0');
  final vat = TextEditingController(text: '23');
  final routeName = TextEditingController(text: 'Dzierżawa');
  int clientId = 0;
  int locationId = 0;
  int productId = 0;
  int routeId = 0;
  int driverId = 0;
  String routeMode = 'existing';
  String paymentMethod = 'cash';
  bool initialFeeCollected = false;
  bool requiresSanitization = false;
  bool saving = false;
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (clients.isNotEmpty) {
      clientId = _int(clients.first['id']);
      final locations = _maps(clients.first['locations']);
      if (locations.isNotEmpty) locationId = _int(locations.first['id']);
    }
    if (products.isNotEmpty) {
      _selectProduct(_int(products.first['id']), notify: false);
    }
    if (routes.isNotEmpty) {
      routeId = _int(routes.first['id']);
    } else {
      routeMode = 'new';
    }
    if (drivers.isNotEmpty) driverId = _int(drivers.first['id']);
  }

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    vat.dispose();
    routeName.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get locations {
    final client = clients.firstWhere(
      (item) => _int(item['id']) == clientId,
      orElse: () => const <String, dynamic>{},
    );
    return _maps(client['locations']);
  }

  void _selectProduct(int value, {bool notify = true}) {
    final product = products.firstWhere(
      (item) => _int(item['id']) == value,
      orElse: () => const <String, dynamic>{},
    );
    void update() {
      productId = value;
      price.text = '${product['default_price'] ?? 0}';
      vat.text = '${product['vat_rate'] ?? 23}';
      requiresSanitization = '${product['name'] ?? ''}'.toLowerCase().contains(
        'dystrybutor',
      );
    }

    notify ? setState(update) : update();
  }

  Future<void> _save() async {
    final count = int.tryParse(quantity.text) ?? 0;
    if (clientId < 1 ||
        locationId < 1 ||
        productId < 1 ||
        count < 1 ||
        (routeMode == 'existing' && routeId < 1) ||
        (routeMode == 'new' &&
            (driverId < 1 || routeName.text.trim().isEmpty))) {
      _snack(
        context,
        'Uzupełnij klienta, lokalizację, model i trasę.',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      final response = await ref.read(adminRepositoryProvider).storeRental(
        ref.read(authControllerProvider).session!.token,
        <String, dynamic>{
          'client_id': clientId,
          'client_location_id': locationId,
          'product_id': productId,
          'quantity': count,
          'unit_price_net':
              double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
          'vat_rate': double.tryParse(vat.text.replaceAll(',', '.')) ?? 23,
          'initial_fee_collected': initialFeeCollected,
          'requires_sanitization': requiresSanitization,
          'payment_method': paymentMethod,
          'route_mode': routeMode,
          'delivery_route_id': routeMode == 'existing' ? routeId : null,
          'route_name': routeMode == 'new' ? routeName.text.trim() : null,
          'scheduled_date': routeMode == 'new' ? _isoDate(date) : null,
          'driver_id': routeMode == 'new' ? driverId : null,
        },
      );
      if (mounted) {
        Navigator.pop(context, true);
        _snack(
          context,
          '${response['message'] ?? 'Dzierżawa została dodana.'}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        _snack(context, '$error', error: true);
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
                  'Nowa dzierżawa',
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
              DropdownButtonFormField<int>(
                initialValue: clientId == 0 ? null : clientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Klient'),
                items: clients
                    .map(
                      (client) => DropdownMenuItem(
                        value: _int(client['id']),
                        child: Text(
                          '${client['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    clientId = value;
                    final nextLocations = locations;
                    locationId = nextLocations.isEmpty
                        ? 0
                        : _int(nextLocations.first['id']);
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('rental-location-$clientId'),
                initialValue: locationId == 0 ? null : locationId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lokalizacja'),
                items: locations
                    .map(
                      (location) => DropdownMenuItem(
                        value: _int(location['id']),
                        child: Text(
                          '${location['name']} - ${location['address'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => locationId = value ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: productId == 0 ? null : productId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sprzęt / przedmiot dzierżawy',
                ),
                items: products
                    .map(
                      (product) => DropdownMenuItem(
                        value: _int(product['id']),
                        child: Text(
                          '${product['name']} (stan: ${product['stock']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _selectProduct(value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ilość'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cena netto / szt.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: vat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'VAT %'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: initialFeeCollected,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Pobrano opłatę za dzierżawę za bieżący miesiąc',
                ),
                subtitle: const Text(
                  'Kwota trafi na to WZ i nie naliczy się drugi raz w tym miesiącu. Od kolejnego miesiąca będzie rozliczana automatycznie.',
                ),
                onChanged: (value) =>
                    setState(() => initialFeeCollected = value ?? false),
              ),
              if (initialFeeCollected) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Płatność przy wydaniu',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Gotówka')),
                    DropdownMenuItem(value: 'transfer', child: Text('Przelew')),
                  ],
                  onChanged: (value) =>
                      setState(() => paymentMethod = value ?? 'cash'),
                ),
              ],
              CheckboxListTile(
                value: requiresSanitization,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Sprzęt wymaga regularnej sanityzacji'),
                subtitle: const Text(
                  'Włączone automatycznie dla dystrybutorów; stojaki, misy i pompki tego nie wymagają.',
                ),
                onChanged: (value) =>
                    setState(() => requiresSanitization = value ?? false),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'existing',
                    label: Text('Istniejąca trasa'),
                  ),
                  ButtonSegment(value: 'new', label: Text('Nowa trasa')),
                ],
                selected: {routeMode},
                onSelectionChanged: (value) =>
                    setState(() => routeMode = value.first),
              ),
              const SizedBox(height: 12),
              if (routeMode == 'existing')
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
                  onChanged: (value) => setState(() => routeId = value ?? 0),
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
                  title: const Text('Data trasy'),
                  subtitle: Text(_isoDate(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: driverId == 0 ? null : driverId,
                  isExpanded: true,
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
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Dodaj dzierżawę do trasy'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AdminRouteNotesScreen extends ConsumerStatefulWidget {
  const AdminRouteNotesScreen({super.key});
  @override
  ConsumerState<AdminRouteNotesScreen> createState() =>
      _AdminRouteNotesScreenState();
}

class _AdminRouteNotesScreenState extends ConsumerState<AdminRouteNotesScreen> {
  int? routeId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Uwagi do tras')),
    bottomNavigationBar: adminBottomNavigation(context, ref),
    body: ref
        .watch(adminRouteNotesProvider(routeId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Error(
            '$e',
            () => ref.invalidate(adminRouteNotesProvider(routeId)),
          ),
          data: (data) {
            final routes = _maps(data['routes']);
            final stops = _maps(data['stops']);
            routeId ??= int.tryParse('${data['selected_route_id'] ?? ''}');
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<int>(
                    initialValue: routeId,
                    isExpanded: true,
                    items: routes
                        .map(
                          (r) => DropdownMenuItem(
                            value: int.tryParse('${r['id']}'),
                            child: Text(
                              '${r['scheduled_date']} - ${r['name']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => routeId = v),
                    decoration: const InputDecoration(labelText: 'Trasa'),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: stops.length,
                    itemBuilder: (_, i) {
                      final stop = stops[i];
                      return ListTile(
                        title: Text('${stop['name']}'),
                        subtitle: Text(
                          '${stop['address']}\n${stop['note'] ?? 'Brak aktywnej uwagi'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit_note),
                        onTap: () => _editNote(stop),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
  );
  Future<void> _editNote(Map<String, dynamic> stop) async {
    final note = TextEditingController(text: '${stop['note'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${stop['name']}'),
        content: TextField(
          controller: note,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Uwaga dla kierowcy'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    if (ok != true || routeId == null) return;
    await ref
        .read(adminRepositoryProvider)
        .saveRouteNote(
          ref.read(authControllerProvider).session!.token,
          routeId: routeId!,
          clientId: int.parse('${stop['client_id']}'),
          locationId: int.tryParse('${stop['client_location_id']}'),
          note: note.text,
        );
    ref.invalidate(adminRouteNotesProvider(routeId));
  }
}

class _ManagementTabs extends StatelessWidget {
  const _ManagementTabs({
    required this.selected,
    required this.tabs,
    required this.onChanged,
  });

  final String selected;
  final List<(String, String, int)> tabs;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4FF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD8DEEC)),
    ),
    child: Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: Material(
              color: selected == tab.$1 ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onChanged(tab.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 11,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${tab.$2}  ${tab.$3}',
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected == tab.$1
                            ? const Color(0xFF4057F4)
                            : const Color(0xFF667085),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error(this.text, this.retry);
  final String text;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, textAlign: TextAlign.center),
        TextButton(onPressed: retry, child: const Text('Ponów')),
      ],
    ),
  );
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

int _int(dynamic value) => int.tryParse('$value') ?? 0;
double _double(dynamic value) =>
    double.tryParse('$value'.replaceAll(',', '.')) ?? 0;
String _money(dynamic value) =>
    '${_double(value).toStringAsFixed(2).replaceAll('.', ',')} zł';
String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : null,
    ),
  );
}
