import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import '../domain/rental_sanitization_rules.dart';
import 'admin_bottom_navigation.dart';

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
  List<Map<String, dynamic>> _trialRoutes = [];
  List<Map<String, dynamic>> _drivers = [];
  final List<Map<String, dynamic>> _trialItems = [];
  Set<int> _visibleProducts = {};
  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  bool _recipient = false;
  bool _jst = false;
  bool _recurringRentalInvoice = false;
  bool _emailMonthlyWzWithInvoice = false;
  String _payment = 'transfer';
  String _productQuery = '';
  bool _trialEnabled = false;
  int _trialDurationDays = 14;
  String? _trialLocationUid;
  String _trialRouteMode = 'new';
  int? _trialRouteId;
  int? _trialDriverId;
  late final TextEditingController _trialRouteName;
  late final TextEditingController _trialDate;
  late final TextEditingController _trialNotes;

  List<Map<String, dynamic>> get _rentalProducts {
    final existingIds = _rentals
        .map((item) => _int(item['product_id']))
        .where((id) => id > 0)
        .toSet();

    return _products
        .where(
          (product) =>
              _bool(product['available_for_rental']) ||
              existingIds.contains(_int(product['id'])),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _availableRentalProducts => _products
      .where((product) => _bool(product['available_for_rental']))
      .toList();

  List<Map<String, dynamic>> get _trialProducts => _products
      .where((product) => '${product['kind'] ?? 'product'}' != 'service')
      .toList();

  @override
  void initState() {
    super.initState();
    _trialRouteName = TextEditingController(text: 'Testy');
    _trialDate = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    _trialNotes = TextEditingController();
    _trialItems.add(_newTrialItem());
    _tabs = TabController(
      length: 5,
      initialIndex: widget.initialTab.clamp(0, 4),
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _trialRouteName.dispose();
    _trialDate.dispose();
    _trialNotes.dispose();
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
      _trialRoutes = _maps(response['routes']);
      _drivers = _maps(response['drivers']);
      _locations = _maps(_client['locations']);
      _rentals = _maps(_client['rental_items']);
      _visibleProducts = _ints(_client['visible_product_ids']).toSet();
      final prices = _map(_client['prices']);
      for (final product in _products) {
        final id = _int(product['id']);
        _priceControllers[id] = TextEditingController(
          text: prices['$id']?.toString() ?? '',
        );
      }
      _active = _bool(_client['is_active']);
      _recipient = _bool(_client['invoice_recipient_enabled']);
      _jst = _bool(_client['invoice_jst_enabled']);
      _recurringRentalInvoice = _bool(
        _client['dispenser_recurring_invoice_enabled'],
      );
      _emailMonthlyWzWithInvoice = _bool(
        _client['email_monthly_wz_with_invoice'],
      );
      _payment = _client['payment_method']?.toString() == 'cash'
          ? 'cash'
          : 'transfer';
      if (_locations.isEmpty) _addLocation();
      _trialLocationUid ??= '${_defaultLocation['uid'] ?? ''}';
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
    if (widget.id == null && _trialEnabled) {
      if (_trialItems.isEmpty ||
          _trialItems.any(
            (item) =>
                _int(item['product_id']) < 1 || _int(item['quantity']) < 1,
          )) {
        _tabs.index = 4;
        _error('Wybierz produkty i ilości wydawane na testy.');
        return;
      }
      if (_trialRouteMode == 'existing' && _trialRouteId == null) {
        _tabs.index = 4;
        _error('Wybierz trasę wydania testów.');
        return;
      }
      if (_trialRouteMode == 'new' && _trialDriverId == null) {
        _tabs.index = 4;
        _error('Wybierz kierowcę nowej trasy testowej.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final session = ref.read(authControllerProvider).session!;
      final prices = <String, dynamic>{};
      for (final entry in _priceControllers.entries) {
        final value = entry.value.text.trim().replaceAll(',', '.');
        if (value.isNotEmpty) prices['${entry.key}'] = value;
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
        'email_monthly_wz_with_invoice': _emailMonthlyWzWithInvoice,
        'locations': _locations,
        'visible_product_ids': _visibleProducts.toList(),
        'prices': prices,
        'rental_items': _rentals,
        if (widget.id == null)
          'trial': {
            'enabled': _trialEnabled,
            if (_trialEnabled) ...{
              'duration_days': _trialDurationDays,
              'client_location_uid': _trialLocationUid,
              'notes': _trialNotes.text.trim(),
              'items': _trialItems,
              'route_mode': _trialRouteMode,
              'delivery_route_id': _trialRouteMode == 'existing'
                  ? _trialRouteId
                  : null,
              'route_name': _trialRouteMode == 'new'
                  ? _trialRouteName.text.trim()
                  : null,
              'scheduled_date': _trialRouteMode == 'new'
                  ? _trialDate.text.trim()
                  : null,
              'driver_id': _trialRouteMode == 'new' ? _trialDriverId : null,
            },
          },
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
      'packages': <Map<String, dynamic>>[],
      'is_active': true,
      'invoice_recipient_enabled': false,
      'invoice_recipient_jst': false,
    });
    _trialLocationUid ??= uid;
  }

  Map<String, dynamic> _newTrialItem() => {
    'product_id': null,
    'quantity': 1,
    'is_rental': false,
  };

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
          Tab(text: 'Testy'),
        ],
      ),
    ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: WntColors.line)),
            ),
            child: SizedBox(
              width: double.infinity,
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
        ),
        adminBottomNavigation(context, ref),
      ],
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
                _trialsTab(),
              ],
            ),
          ),
  );

  Widget _trialsTab() {
    if (widget.id != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 40,
                    color: WntColors.brand,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Aktywne testy i decyzje po terminie są dostępne na ekranie „Klienci testowi”.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Klient otrzymuje produkty na testy'),
                  subtitle: const Text(
                    'Stan magazynu zmieni się dopiero po podpisanym wydaniu. WZ będzie miało wartość 0,00 zł.',
                  ),
                  value: _trialEnabled,
                  onChanged: (value) => setState(() => _trialEnabled = value),
                ),
                if (_trialEnabled) ...[
                  const Divider(),
                  TextFormField(
                    initialValue: '$_trialDurationDays',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Liczba dni testów',
                    ),
                    onChanged: (value) =>
                        _trialDurationDays = int.tryParse(value) ?? 14,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _trialLocationUid,
                    decoration: const InputDecoration(
                      labelText: 'Lokalizacja wydania',
                    ),
                    items: [
                      for (final location in _locations)
                        DropdownMenuItem(
                          value: '${location['uid']}',
                          child: Text('${location['name']}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _trialLocationUid = value),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Co klient dostaje',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < _trialItems.length; index++) ...[
                    _trialItemCard(index),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _trialItems.add(_newTrialItem())),
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj kolejną pozycję'),
                  ),
                  const Divider(height: 30),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'existing',
                        label: Text('Istniejąca trasa'),
                      ),
                      ButtonSegment(value: 'new', label: Text('Nowa trasa')),
                    ],
                    selected: {_trialRouteMode},
                    onSelectionChanged: (value) =>
                        setState(() => _trialRouteMode = value.first),
                  ),
                  const SizedBox(height: 10),
                  if (_trialRouteMode == 'existing')
                    DropdownButtonFormField<int>(
                      initialValue: _trialRouteId,
                      decoration: const InputDecoration(
                        labelText: 'Trasa wydania',
                      ),
                      items: [
                        for (final route in _trialRoutes)
                          DropdownMenuItem(
                            value: _int(route['id']),
                            child: Text(
                              '${route['date']} — ${route['name']} — ${route['driver'] ?? ''}',
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _trialRouteId = value),
                    )
                  else ...[
                    TextField(
                      controller: _trialRouteName,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa trasy',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _trialDate,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Data wydania',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(_trialDate.text) ??
                              DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (selected != null) {
                          _trialDate.text = selected
                              .toIso8601String()
                              .substring(0, 10);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _trialDriverId,
                      decoration: const InputDecoration(labelText: 'Kierowca'),
                      items: [
                        for (final driver in _drivers)
                          DropdownMenuItem(
                            value: _int(driver['id']),
                            child: Text('${driver['name']}'),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _trialDriverId = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _trialNotes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Uwagi do testów',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trialItemCard(int index) {
    final item = _trialItems[index];
    final product = _trialProducts.cast<Map<String, dynamic>?>().firstWhere(
      (candidate) => _int(candidate?['id']) == _int(item['product_id']),
      orElse: () => null,
    );
    final canRent = _bool(product?['available_for_rental']);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WntColors.canvas,
        border: Border.all(color: WntColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: _int(item['product_id']) > 0
                ? _int(item['product_id'])
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Produkt / sprzęt'),
            items: [
              for (final option in _trialProducts)
                DropdownMenuItem(
                  value: _int(option['id']),
                  child: Text(
                    '${option['name']} (stan: ${_int(option['stock'])} ${option['unit'] ?? 'szt.'})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              item['product_id'] = value;
              final selected = _trialProducts.firstWhere(
                (option) => _int(option['id']) == value,
              );
              item['is_rental'] = _bool(selected['available_for_rental']);
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${_int(item['quantity']).clamp(1, 999999)}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ilość'),
                  onChanged: (value) => item['quantity'] = int.tryParse(value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sprzęt do zwrotu (automatycznie)'),
                  value: canRent && _bool(item['is_rental']),
                  onChanged: null,
                ),
              ),
              IconButton(
                tooltip: 'Usuń',
                onPressed: _trialItems.length > 1
                    ? () => setState(() => _trialItems.removeAt(index))
                    : null,
                icon: const Icon(Icons.delete_outline, color: WntColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          title: const Text('Wyślij fakturę ze wszystkimi WZ z miesiąca'),
          subtitle: const Text(
            'Jeden email będzie zawierał fakturę miesięczną oraz komplet WZ objętych rozliczeniem.',
          ),
          value: _emailMonthlyWzWithInvoice,
          onChanged: (value) =>
              setState(() => _emailMonthlyWzWithInvoice = value),
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
          _mapField(location, 'document_notes', 'Uwagi do WZ/FV'),
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
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pakiety',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => _editLocationPackage(index),
                icon: const Icon(Icons.add),
                label: const Text('Dodaj pakiet'),
              ),
            ],
          ),
          for (final package in _maps(location['packages']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('${package['name'] ?? 'Pakiet'}'),
              subtitle: Text(
                '${package['price'] ?? 0} zł - ${_maps(package['components']).map((item) => '${item['name']} x ${_int(item['quantity'])}').join(', ')}',
              ),
              onTap: () => _editLocationPackage(index, package: package),
              trailing: IconButton(
                tooltip: 'Usuń pakiet',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() {
                  final packages = _maps(location['packages']);
                  packages.remove(package);
                  location['packages'] = packages;
                }),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _editLocationPackage(
    int locationIndex, {
    Map<String, dynamic>? package,
  }) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _LocationPackageEditor(products: _products, initial: package),
    );
    if (result == null || !mounted) return;
    setState(() {
      final packages = _maps(_locations[locationIndex]['packages']);
      _locations[locationIndex]['packages'] = packages;
      if (package == null) {
        packages.add(result);
      } else {
        final packageIndex = packages.indexOf(package);
        if (packageIndex >= 0) packages[packageIndex] = result;
      }
    });
  }

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
                            price.text =
                                product['default_price']?.toString() ?? '0';
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
                      width: 104,
                      child: TextField(
                        controller: _priceControllers[id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'cena',
                          suffixText: 'zł',
                        ),
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
            onChanged: (value) =>
                setState(() => _recurringRentalInvoice = value),
          ),
        ]);
      }
      if (index == _rentals.length + 1) {
        return OutlinedButton.icon(
          onPressed: _locations.isEmpty || _availableRentalProducts.isEmpty
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
    final product = _availableRentalProducts.first;
    return {
      'client_location_id': _defaultLocation['id'],
      'client_location_uid': _defaultLocation['uid'],
      'product_id': _int(product['id']),
      'quantity': 1,
      'unit_price_net': product['default_price']?.toString() ?? '0',
      'vat_rate': product['vat_rate']?.toString() ?? '23',
      'requires_sanitization': rentalProductRequiresSanitization(
        product['name'],
      ),
      'sanitization_price_net': null,
      'equipment_label': '',
      'last_sanitized_on': _controller('last_sanitized_on').text.trim(),
      'sanitization_interval_days':
          int.tryParse(_controller('sanitization_interval_days').text) ?? 180,
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
                _rentalProducts.any(
                  (item) => _int(item['id']) == _int(rental['product_id']),
                )
                ? _int(rental['product_id'])
                : null,
            decoration: const InputDecoration(labelText: 'Produkt / usługa'),
            items: _rentalProducts
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
            onChanged: (value) {
              final product = _rentalProducts.firstWhere(
                (item) => _int(item['id']) == value,
                orElse: () => const <String, dynamic>{},
              );
              setState(() {
                rental['product_id'] = value;
                rental['requires_sanitization'] =
                    rentalProductRequiresSanitization(product['name']) ||
                    _bool(rental['requires_sanitization']);
              });
            },
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
            value: _rentalRequiresSanitization(rental),
            onChanged: _rentalProductRequiresSanitization(rental)
                ? null
                : (value) =>
                      setState(() => rental['requires_sanitization'] = value),
          ),
          if (_rentalRequiresSanitization(rental)) ...[
            _rentalText(
              rental,
              'equipment_label',
              'Miejsce / oznaczenie (np. Lakiernia)',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _rentalText(
                    rental,
                    'last_sanitized_on',
                    'Ostatnia sanityzacja',
                    keyboard: TextInputType.datetime,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _rentalNumber(
                    rental,
                    'sanitization_interval_days',
                    'Co ile dni',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _rentalNumber(
              rental,
              'sanitization_price_net',
              'Cena sanityzacji netto',
            ),
          ],
        ],
      ),
    ),
  );

  bool _rentalProductRequiresSanitization(Map<String, dynamic> rental) {
    final product = _rentalProducts.firstWhere(
      (item) => _int(item['id']) == _int(rental['product_id']),
      orElse: () => const <String, dynamic>{},
    );

    return rentalProductRequiresSanitization(product['name']);
  }

  bool _rentalRequiresSanitization(Map<String, dynamic> rental) =>
      _rentalProductRequiresSanitization(rental) ||
      _bool(rental['requires_sanitization']);

  Widget _rentalNumber(Map<String, dynamic> rental, String key, String label) =>
      TextFormField(
        initialValue: rental[key]?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (value) => rental[key] = value.replaceAll(',', '.'),
      );

  Widget _rentalText(
    Map<String, dynamic> rental,
    String key,
    String label, {
    TextInputType? keyboard,
  }) => TextFormField(
    initialValue: rental[key]?.toString() ?? '',
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label),
    onChanged: (value) => rental[key] = value.trim(),
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

class _LocationPackageEditor extends StatefulWidget {
  const _LocationPackageEditor({required this.products, this.initial});
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic>? initial;

  @override
  State<_LocationPackageEditor> createState() => _LocationPackageEditorState();
}

class _LocationPackageEditorState extends State<_LocationPackageEditor> {
  late final TextEditingController name = TextEditingController(
    text: widget.initial?['name']?.toString() ?? '',
  );
  late final TextEditingController price = TextEditingController(
    text: widget.initial?['price']?.toString() ?? '',
  );
  late final TextEditingController vat = TextEditingController(
    text: widget.initial?['vat_rate']?.toString() ?? '23',
  );
  late final Map<int, int> quantities = {
    for (final item in _maps(widget.initial?['components']))
      _int(item['product_id']): _int(item['quantity']),
  };
  late final Set<int> rentalIds = {
    for (final item in _maps(widget.initial?['components']))
      if (_bool(item['is_rental'])) _int(item['product_id']),
  };

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    vat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .94,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Pakiet lokalizacji',
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
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: name,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Nazwa pakietu'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 105,
                child: TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cena'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 78,
                child: TextField(
                  controller: vat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'VAT %'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: widget.products.length,
            itemBuilder: (context, index) {
              final product = widget.products[index];
              final id = _int(product['id']);
              final quantity = quantities[id] ?? 0;
              return ListTile(
                title: Text('${product['name']}'),
                subtitle: quantity > 0
                    ? CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Element dzierżawy'),
                        value: rentalIds.contains(id),
                        onChanged: (value) => setState(
                          () => value == true
                              ? rentalIds.add(id)
                              : rentalIds.remove(id),
                        ),
                      )
                    : null,
                trailing: _PackageCounter(
                  value: quantity,
                  onChanged: (value) => setState(() {
                    if (value < 1) {
                      quantities.remove(id);
                      rentalIds.remove(id);
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
                onPressed: name.text.trim().isEmpty || quantities.isEmpty
                    ? null
                    : () => Navigator.pop(context, {
                        if (widget.initial?['id'] != null)
                          'id': widget.initial!['id'],
                        'name': name.text.trim(),
                        'price': price.text.trim().isEmpty
                            ? '0'
                            : price.text.trim(),
                        'vat_rate': vat.text.trim().isEmpty
                            ? '23'
                            : vat.text.trim(),
                        'is_active': true,
                        'components': [
                          for (final entry in quantities.entries)
                            {
                              'product_id': entry.key,
                              'name': widget.products.firstWhere(
                                (item) => _int(item['id']) == entry.key,
                              )['name'],
                              'quantity': entry.value,
                              'is_rental': rentalIds.contains(entry.key),
                            },
                        ],
                      }),
                child: const Text('Zapisz pakiet'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PackageCounter extends StatelessWidget {
  const _PackageCounter({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: value > 0 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
      IconButton(
        onPressed: () => onChanged(value + 1),
        icon: const Icon(Icons.add),
      ),
    ],
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
