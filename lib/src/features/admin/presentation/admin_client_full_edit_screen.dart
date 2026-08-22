import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';

class AdminClientFullEditScreen extends ConsumerStatefulWidget {
  const AdminClientFullEditScreen({this.id, this.initialTab = 0, super.key});

  final int? id;
  final int initialTab;

  @override
  ConsumerState<AdminClientFullEditScreen> createState() =>
      _AdminClientFullEditScreenState();
}

class _AdminClientFullEditScreenState
    extends ConsumerState<AdminClientFullEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _priceControllers = <int, TextEditingController>{};
  late final TabController _tabs;
  Map<String, dynamic> _client = {};
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _rentals = [];
  Set<int> _visibleProducts = {};
  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  bool _recipient = false;
  bool _jst = false;
  bool _recurringRentalInvoice = false;
  String _payment = 'transfer';
  String _productQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      initialIndex: widget.initialTab.clamp(0, 3),
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in [
      ..._controllers.values,
      ..._priceControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: _client[key]?.toString() ?? ''),
  );

  Future<void> _load() async {
    try {
      final session = ref.read(authControllerProvider).session!;
      final response = widget.id == null
          ? await ref.read(adminRepositoryProvider).clientOptions(session.token)
          : await ref
                .read(adminRepositoryProvider)
                .client(session.token, widget.id!);
      _client = widget.id == null
          ? {
              'payment_method': 'transfer',
              'payment_term_days': 14,
              'sanitization_interval_days': 180,
              'is_active': true,
            }
          : _map(response['client']);
      _products = _maps(response['products']);
      _locations = _maps(_client['locations']);
      _rentals = _maps(_client['rental_items']);
      _visibleProducts = _ints(_client['visible_product_ids']).toSet();
      _recurringRentalInvoice = _bool(
        _client['dispenser_recurring_invoice_enabled'],
      );
      final prices = _map(_client['prices']);
      for (final product in _products) {
        final id = _int(product['id']);
        final net = double.tryParse('${prices['$id'] ?? ''}');
        _priceControllers[id] = TextEditingController(
          text: net == null
              ? ''
              : _priceText(
                  _recurringRentalInvoice ? net * _vatFactor(product) : net,
                ),
        );
      }
      _active = _bool(_client['is_active']);
      _recipient = _bool(_client['invoice_recipient_enabled']);
      _jst = _bool(_client['invoice_jst_enabled']);
      _payment = _client['payment_method']?.toString() == 'cash'
          ? 'cash'
          : 'transfer';
      if (_locations.isEmpty) _addLocation();
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_locations.where((item) => _bool(item['is_active'])).isEmpty) {
      _tabs.index = 1;
      _error('Dodaj co najmniej jedną aktywną lokalizację.');
      return;
    }
    setState(() => _saving = true);
    try {
      final session = ref.read(authControllerProvider).session!;
      final prices = <String, dynamic>{};
      for (final entry in _priceControllers.entries) {
        final value = entry.value.text.trim().replaceAll(',', '.');
        if (value.isNotEmpty) {
          final entered = double.tryParse(value);
          final product = _products.firstWhere(
            (item) => _int(item['id']) == entry.key,
            orElse: () => const <String, dynamic>{},
          );
          prices['${entry.key}'] = entered == null
              ? value
              : _priceText(
                  _recurringRentalInvoice
                      ? entered / _vatFactor(product)
                      : entered,
                );
        }
      }
      final payload = {
        for (final key in [
          'name',
          'contact_person',
          'email',
          'phone',
          'invoice_name',
          'invoice_nip',
          'invoice_address',
          'invoice_recipient_name',
          'invoice_recipient_nip',
          'invoice_recipient_address',
          'invoice_recipient_email',
        ])
          key: _controller(key).text.trim(),
        'delivery_address': _defaultLocation['address']?.toString() ?? '',
        'invoice_recipient_enabled': _recipient,
        'invoice_recipient_jst': _recipient && _jst,
        'invoice_jst_enabled': _jst,
        'payment_method': _payment,
        'payment_term_days':
            int.tryParse(_controller('payment_term_days').text) ?? 0,
        'is_active': _active,
        'sanitization_interval_days':
            int.tryParse(_controller('sanitization_interval_days').text) ?? 180,
        'last_sanitized_on': _controller('last_sanitized_on').text.trim(),
        'dispenser_recurring_invoice_enabled': _recurringRentalInvoice,
        'locations': _locations,
        'visible_product_ids': _visibleProducts.toList(),
        'prices': prices,
        'rental_items': _rentals,
      };
      final response = widget.id == null
          ? await ref
                .read(adminRepositoryProvider)
                .createClient(session.token, payload)
          : await ref
                .read(adminRepositoryProvider)
                .updateClient(session.token, widget.id!, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ??
                'Klient i wszystkie dane zostały zapisane.',
          ),
          backgroundColor: WntColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> get _defaultLocation => _locations.firstWhere(
    (item) => _bool(item['is_default']),
    orElse: () => _locations.first,
  );

  void _addLocation() {
    final uid = 'mobile-${DateTime.now().microsecondsSinceEpoch}';
    _locations.add({
      'uid': uid,
      'name': _locations.isEmpty ? 'Siedziba firmy' : 'Nowa lokalizacja',
      'address': '',
      'phone': '',
      'email': '',
      'region': '',
      'delivery_window': '',
      'latitude': null,
      'longitude': null,
      'is_default': _locations.isEmpty,
      'is_active': true,
      'invoice_recipient_enabled': false,
      'invoice_recipient_jst': false,
    });
  }

  void _setDefaultLocation(int index) {
    for (var i = 0; i < _locations.length; i++) {
      _locations[i]['is_default'] = i == index;
    }
    setState(() {});
  }

  Future<void> _gusInvoice() async {
    final nip = _controller('invoice_nip').text.trim();
    if (nip.isEmpty) {
      _error('Wpisz NIP.');
      return;
    }
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref.read(adminRepositoryProvider).gus(token, nip);
      final company = _map(response['company']);
      _controller('invoice_name').text = '${company['name'] ?? ''}';
      _controller('invoice_address').text = '${company['address'] ?? ''}';
      if (_controller('name').text.trim().isEmpty) {
        _controller('name').text = '${company['name'] ?? ''}';
      }
      setState(() {});
    } catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _gusLocation(Map<String, dynamic> location) async {
    final nip = '${location['invoice_recipient_nip'] ?? ''}'.trim();
    if (nip.isEmpty) {
      _error('Wpisz NIP odbiorcy.');
      return;
    }
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref.read(adminRepositoryProvider).gus(token, nip);
      final company = _map(response['company']);
      setState(() {
        location['invoice_recipient_name'] = company['name'] ?? '';
        location['invoice_recipient_address'] = company['address'] ?? '';
      });
    } catch (error) {
      if (mounted) _error(error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.id == null ? 'Nowy klient' : 'Edytuj klienta'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Dane'),
          Tab(text: 'Lokalizacje'),
          Tab(text: 'Produkty'),
          Tab(text: 'Dzierżawy'),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: WntColors.line)),
        ),
        child: FilledButton.icon(
          onPressed: _saving || _loading ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _saving
                ? 'Zapisywanie...'
                : widget.id == null
                ? 'Dodaj klienta'
                : 'Zapisz zmiany',
          ),
        ),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabs,
              children: [
                _detailsTab(),
                _locationsTab(),
                _productsTab(),
                _rentalsTab(),
              ],
            ),
          ),
  );

  Widget _detailsTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _section('Dane podstawowe', [
        _field('name', 'Nazwa klienta', required: true),
        _field('contact_person', 'Osoba kontaktowa'),
        _field('phone', 'Telefon', keyboard: TextInputType.phone),
        _field('email', 'Email', keyboard: TextInputType.emailAddress),
      ]),
      const SizedBox(height: 12),
      _section('Dane do faktury', [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _field('invoice_nip', 'NIP')),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Pobierz dane z GUS',
              onPressed: _gusInvoice,
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        _field('invoice_name', 'Nazwa do faktury'),
        _field('invoice_address', 'Adres do faktury', lines: 2),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Faktura dla jednostki samorządowej'),
          value: _jst,
          onChanged: (value) => setState(() => _jst = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dane odbiorcy'),
          value: _recipient,
          onChanged: (value) => setState(() => _recipient = value),
        ),
        if (_recipient) ...[
          _field('invoice_recipient_name', 'Nazwa odbiorcy'),
          _field('invoice_recipient_nip', 'NIP odbiorcy'),
          _field('invoice_recipient_address', 'Adres odbiorcy', lines: 2),
          _field(
            'invoice_recipient_email',
            'Email odbiorcy',
            keyboard: TextInputType.emailAddress,
          ),
        ],
      ]),
      const SizedBox(height: 12),
      _section('Rozliczenia', [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'cash', label: Text('Gotówka')),
            ButtonSegment(value: 'transfer', label: Text('Przelew')),
          ],
          selected: {_payment},
          onSelectionChanged: (value) => setState(() => _payment = value.first),
        ),
        const SizedBox(height: 12),
        _field(
          'payment_term_days',
          'Termin płatności w dniach',
          keyboard: TextInputType.number,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Klient aktywny'),
          value: _active,
          onChanged: (value) => setState(() => _active = value),
        ),
      ]),
    ],
  );

  Widget _locationsTab() => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: _locations.length + 1,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      if (index == _locations.length) {
        return OutlinedButton.icon(
          onPressed: () => setState(_addLocation),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Dodaj lokalizację'),
        );
      }
      final location = _locations[index];
      return _locationCard(index, location);
    },
  );

  Widget _locationCard(int index, Map<String, dynamic> location) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _bool(location['is_default'])
                      ? 'Siedziba firmy'
                      : 'Lokalizacja ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!_bool(location['is_default']))
                IconButton(
                  tooltip: 'Ustaw jako główną',
                  onPressed: () => _setDefaultLocation(index),
                  icon: const Icon(Icons.home_outlined),
                ),
            ],
          ),
          _mapField(location, 'name', 'Nazwa lokalizacji', required: true),
          _mapField(location, 'address', 'Adres lokalizacji', required: true),
          _mapField(
            location,
            'phone',
            'Telefon odbiorcy',
            keyboard: TextInputType.phone,
          ),
          _mapField(
            location,
            'email',
            'Email lokalizacji',
            keyboard: TextInputType.emailAddress,
          ),
          _mapField(location, 'region', 'Region'),
          _mapField(location, 'delivery_window', 'Okno dostawy'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lokalizacja aktywna'),
            value: _bool(location['is_active']),
            onChanged: (value) => setState(() => location['is_active'] = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dane odbiorcy dla tej lokalizacji'),
            value: _bool(location['invoice_recipient_enabled']),
            onChanged: (value) =>
                setState(() => location['invoice_recipient_enabled'] = value),
          ),
          if (_bool(location['invoice_recipient_enabled'])) ...[
            _mapField(location, 'invoice_recipient_name', 'Nazwa odbiorcy'),
            _mapField(location, 'invoice_recipient_nip', 'NIP odbiorcy'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _gusLocation(location),
                icon: const Icon(Icons.download_outlined),
                label: const Text('GUS odbiorcy'),
              ),
            ),
            _mapField(location, 'invoice_recipient_address', 'Adres odbiorcy'),
            _mapField(
              location,
              'invoice_recipient_email',
              'Email odbiorcy',
              keyboard: TextInputType.emailAddress,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _productsTab() {
    final query = _productQuery.trim().toLowerCase();
    final items =
        _products.where((product) {
          final visible = _visibleProducts.contains(_int(product['id']));
          return query.isEmpty ||
              visible ||
              product['name'].toString().toLowerCase().contains(query);
        }).toList()..sort((a, b) {
          final av = _visibleProducts.contains(_int(a['id'])) ? 0 : 1;
          final bv = _visibleProducts.contains(_int(b['id'])) ? 0 : 1;
          return av != bv
              ? av.compareTo(bv)
              : a['name'].toString().compareTo(b['name'].toString());
        });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Szukaj produktu lub usługi',
            ),
            onChanged: (value) => setState(() => _productQuery = value),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = items[index];
              final id = _int(product['id']);
              final selected = _visibleProducts.contains(id);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _visibleProducts.add(id);
                          final price = _priceControllers[id];
                          if (price != null && price.text.trim().isEmpty) {
                            final net = double.tryParse(
                                  '${product['default_price'] ?? 0}',
                                ) ??
                                0;
                            price.text = _priceText(
                              _recurringRentalInvoice
                                  ? net * _vatFactor(product)
                                  : net,
                            );
                          }
                        } else {
                          _visibleProducts.remove(id);
                        }
                      }),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['name']?.toString() ?? 'Produkt'),
                          Text(
                            '${product['default_price']} zł / ${product['unit']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 126,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _priceControllers[id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: _recurringRentalInvoice
                                  ? 'Cena brutto'
                                  : 'Cena netto',
                              suffixText: 'zł',
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _secondaryPrice(product, id),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _changeRecurringInvoiceMode(bool enabled) {
    if (enabled == _recurringRentalInvoice) return;
    for (final product in _products) {
      final id = _int(product['id']);
      final controller = _priceControllers[id];
      final current = double.tryParse(
        controller?.text.trim().replaceAll(',', '.') ?? '',
      );
      if (controller == null || current == null) continue;
      controller.text = _priceText(
        enabled ? current * _vatFactor(product) : current / _vatFactor(product),
      );
    }
    setState(() => _recurringRentalInvoice = enabled);
  }

  String _secondaryPrice(Map<String, dynamic> product, int id) {
    final current = double.tryParse(
      _priceControllers[id]?.text.trim().replaceAll(',', '.') ?? '',
    );
    if (current == null) {
      return _recurringRentalInvoice ? 'netto: —' : 'brutto: —';
    }
    final other = _recurringRentalInvoice
        ? current / _vatFactor(product)
        : current * _vatFactor(product);
    return '${_recurringRentalInvoice ? 'netto' : 'brutto'}: ${_priceText(other)} zł';
  }

  double _vatFactor(Map<String, dynamic> product) {
    final vat = double.tryParse('${product['vat_rate'] ?? 23}') ?? 23;
    return 1 + (vat / 100);
  }

  String _priceText(double value) => value.toStringAsFixed(2);

  Widget _rentalsTab() => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: _rentals.length + 2,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      if (index == 0) {
        return _section('Sanityzacja i rozliczenie', [
          _field(
            'last_sanitized_on',
            'Data ostatniej sanityzacji (RRRR-MM-DD)',
            keyboard: TextInputType.datetime,
          ),
          _field(
            'sanitization_interval_days',
            'Sanityzacja co ile dni',
            keyboard: TextInputType.number,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Faktura cykliczna co miesiąc'),
            value: _recurringRentalInvoice,
            onChanged: _changeRecurringInvoiceMode,
          ),
        ]);
      }
      if (index == _rentals.length + 1) {
        return OutlinedButton.icon(
          onPressed: _locations.isEmpty
              ? null
              : () => setState(() => _rentals.add(_newRental())),
          icon: const Icon(Icons.add),
          label: const Text('Dodaj dzierżawę'),
        );
      }
      return _rentalCard(index - 1, _rentals[index - 1]);
    },
  );

  Map<String, dynamic> _newRental() {
    final product = _products.firstWhere(
      (item) => item['name'].toString().toLowerCase().contains('dzierż'),
      orElse: () => _products.first,
    );
    return {
      'client_location_id': _defaultLocation['id'],
      'client_location_uid': _defaultLocation['uid'],
      'product_id': _int(product['id']),
      'quantity': 1,
      'unit_price_net': product['default_price']?.toString() ?? '0',
      'vat_rate': product['vat_rate']?.toString() ?? '23',
      'requires_sanitization': false,
      'sanitization_price_net': null,
    };
  }

  Widget _rentalCard(int index, Map<String, dynamic> rental) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dzierżawa ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Usuń dzierżawę',
                onPressed: () => setState(() => _rentals.removeAt(index)),
                icon: const Icon(Icons.delete_outline, color: WntColors.error),
              ),
            ],
          ),
          DropdownButtonFormField<int>(
            initialValue:
                _products.any(
                  (item) => _int(item['id']) == _int(rental['product_id']),
                )
                ? _int(rental['product_id'])
                : null,
            decoration: const InputDecoration(labelText: 'Produkt / usługa'),
            items: _products
                .map(
                  (item) => DropdownMenuItem(
                    value: _int(item['id']),
                    child: Text(
                      item['name']?.toString() ?? 'Produkt',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => rental['product_id'] = value,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _locationKeyForRental(rental),
            decoration: const InputDecoration(labelText: 'Lokalizacja'),
            items: _locations
                .map(
                  (item) => DropdownMenuItem(
                    value: _locationKey(item),
                    child: Text(
                      item['name']?.toString() ?? 'Lokalizacja',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              final location = _locations.firstWhere(
                (item) => _locationKey(item) == value,
              );
              rental['client_location_id'] = location['id'];
              rental['client_location_uid'] = location['uid'];
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _rentalNumber(rental, 'quantity', 'Ilość')),
              const SizedBox(width: 8),
              Expanded(
                child: _rentalNumber(rental, 'unit_price_net', 'Netto / szt.'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _rentalNumber(rental, 'vat_rate', 'VAT %')),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sanityzacja'),
            value: _bool(rental['requires_sanitization']),
            onChanged: (value) =>
                setState(() => rental['requires_sanitization'] = value),
          ),
          if (_bool(rental['requires_sanitization']))
            _rentalNumber(
              rental,
              'sanitization_price_net',
              'Cena sanityzacji netto',
            ),
        ],
      ),
    ),
  );

  Widget _rentalNumber(Map<String, dynamic> rental, String key, String label) =>
      TextFormField(
        initialValue: rental[key]?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (value) => rental[key] = value.replaceAll(',', '.'),
      );

  String _locationKey(Map<String, dynamic> location) => location['id'] != null
      ? 'id:${location['id']}'
      : 'uid:${location['uid']}';

  String? _locationKeyForRental(Map<String, dynamic> rental) {
    final id = rental['client_location_id'];
    final uid = rental['client_location_uid'];
    final key = id != null
        ? 'id:$id'
        : uid != null
        ? 'uid:$uid'
        : null;
    return _locations.any((item) => _locationKey(item) == key)
        ? key
        : _locations.isEmpty
        ? null
        : _locationKey(_defaultLocation);
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _controller(key),
      keyboardType: keyboard,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) =>
                value?.trim().isEmpty == true ? 'To pole jest wymagane.' : null
          : null,
    ),
  );

  Widget _mapField(
    Map<String, dynamic> data,
    String key,
    String label, {
    bool required = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: data[key]?.toString() ?? '',
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      onChanged: (value) => data[key] = value.trim(),
      validator: required
          ? (value) =>
                value?.trim().isEmpty == true ? 'To pole jest wymagane.' : null
          : null,
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  void _error(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : <Map<String, dynamic>>[];

List<int> _ints(dynamic value) => value is List
    ? value.map(_int).where((item) => item > 0).toList()
    : <int>[];

int _int(dynamic value) => int.tryParse('$value') ?? 0;

bool _bool(dynamic value) => value == true || value == 1 || value == '1';
