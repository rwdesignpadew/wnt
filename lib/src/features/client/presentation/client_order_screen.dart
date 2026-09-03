import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/client_providers.dart';

class ClientOrderScreen extends ConsumerStatefulWidget {
  const ClientOrderScreen({super.key});

  @override
  ConsumerState<ClientOrderScreen> createState() => _ClientOrderScreenState();
}

class _ClientOrderScreenState extends ConsumerState<ClientOrderScreen> {
  final _quantities = <int, int>{};
  final _notes = TextEditingController();
  int? _locationId;
  bool _saving = false;
  bool _showOrderForm = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidate(clientHomeProvider);
      ref.invalidate(clientTrackingProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selected = Map<int, int>.from(_quantities)
      ..removeWhere((_, quantity) => quantity <= 0);
    if (selected.isEmpty) {
      _message('Wybierz przynajmniej jeden produkt.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(clientRepositoryProvider)
          .createOrder(
            token: token,
            locationId: _locationId,
            quantities: selected,
            notes: _notes.text,
          );
      _quantities.clear();
      _notes.clear();
      _showOrderForm = false;
      ref.invalidate(clientHomeProvider);
      _message(
        response['message']?.toString() ?? 'Zamówienie zostało wysłane.',
      );
      if (mounted) setState(() {});
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? WntColors.error : WntColors.success,
      ),
    );
  }

  Future<void> _showOrder(
    Map<String, dynamic> order,
    Map<String, dynamic>? tracking,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final isTracked =
          tracking?['order_number']?.toString() == order['number']?.toString();
      final driver = isTracked && tracking?['driver'] is Map
          ? (tracking!['driver'] as Map).cast<String, dynamic>()
          : null;
      final items = _mapList(order['items']);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .45,
        maxChildSize: .96,
        builder: (context, controller) => Column(
          children: [
            ListTile(
              title: Text(
                order['number']?.toString() ?? 'Zamówienie',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(order['location']?.toString() ?? ''),
              trailing: IconButton(
                tooltip: 'Zamknij',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  _OrderDetail('Status', _orderStatus(order['status'])),
                  _OrderDetail('Data', order['created_at']?.toString() ?? ''),
                  if (isTracked) ...[
                    _OrderDetail(
                      'Adres dostawy',
                      tracking?['address']?.toString() ?? '',
                    ),
                    _OrderDetail(
                      'Kierowca',
                      tracking?['driver_name']?.toString() ??
                          'Jeszcze nie przypisano',
                    ),
                    _OrderDetail(
                      'Szacowana dostawa',
                      tracking?['eta_minutes'] == null
                          ? (tracking?['tracking_active'] == true)
                                ? 'Trwa wyliczanie'
                                : 'Brak aktualnego sygnału GPS samochodu'
                          : 'około ${tracking?['eta_at']} (${tracking?['eta_minutes']} min)',
                    ),
                    _OrderDetail(
                      'GPS samochodu (MyCar)',
                      driver?['recorded_at']?.toString() ?? 'Brak sygnału',
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Produkty',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Text('Brak pozycji zamówienia.')
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < items.length;
                            index++
                          ) ...[
                            ListTile(
                              title: Text(
                                items[index]['name']?.toString() ?? 'Produkt',
                              ),
                              trailing: Text(
                                '${items[index]['quantity'] ?? 0} szt.',
                              ),
                            ),
                            if (index < items.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: WntColors.line)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Razem brutto',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${_money(order['total_gross'] ?? order['total'])} zł',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(clientHomeProvider);
    return home.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(clientHomeProvider),
      ),
      data: (data) {
        final products = _mapList(data['products']);
        final locations = _mapList(data['locations']);
        final orders = _mapList(data['orders']);
        final trackingResponse = ref
            .watch(clientTrackingProvider)
            .asData
            ?.value;
        final tracking = trackingResponse?['tracking'] is Map
            ? (trackingResponse!['tracking'] as Map).cast<String, dynamic>()
            : null;
        final availableLocationIds = locations
            .map((location) => _int(location['id']))
            .where((id) => id > 0)
            .toSet();
        if (_locationId == null ||
            !availableLocationIds.contains(_locationId)) {
          _locationId = _defaultLocation(locations);
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientHomeProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Zamówienia',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        setState(() => _showOrderForm = !_showOrderForm),
                    icon: Icon(_showOrderForm ? Icons.close : Icons.add),
                    label: Text(_showOrderForm ? 'Zamknij' : 'Nowe zamówienie'),
                  ),
                ],
              ),
              if (_showOrderForm) ...[
                const SizedBox(height: 16),
                if (locations.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _locationId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lokalizacja zamawiająca',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: locations
                        .map(
                          (location) => DropdownMenuItem<int>(
                            value: _int(location['id']),
                            child: Text(
                              _locationLabel(location),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _locationId = value),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  'Wybierz produkty i ich ilości.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      for (var index = 0; index < products.length; index++) ...[
                        _ProductRow(
                          product: products[index],
                          quantity:
                              _quantities[_int(products[index]['id'])] ?? 0,
                          onChanged: (quantity) => setState(
                            () => _quantities[_int(products[index]['id'])] =
                                quantity,
                          ),
                        ),
                        if (index < products.length - 1) const Divider(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Uwagi do zamówienia',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(_saving ? 'Wysyłanie...' : 'Wyślij zamówienie'),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Twoje zamówienia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (orders.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.shopping_cart_outlined),
                    title: Text('Brak zamówień'),
                  ),
                )
              else
                for (final order in orders)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.shopping_cart_outlined),
                      title: Text(
                        order['number']?.toString() ??
                            'Zamówienie #${order['id']}',
                      ),
                      subtitle: Text(
                        '${_orderStatus(order['status'])} · '
                        '${order['total_gross'] ?? order['total'] ?? ''} zł',
                      ),
                      trailing: Text(
                        order['created_at']?.toString() ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => _showOrder(order, tracking),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: WntColors.muted)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _orderStatus(dynamic value) => switch ('$value') {
  'overdue' => 'Opóźnione — oczekuje na trasę',
  'new' => 'Oczekujące',
  'accepted' => 'Przyjęte',
  'planned' => 'Zaplanowane',
  'in_delivery' => 'W dostawie',
  'completed' => 'Zrealizowane',
  'cancelled' => 'Anulowane',
  _ => '$value',
};

String _money(dynamic value) =>
    (double.tryParse('$value') ?? 0).toStringAsFixed(2).replaceFirst('.', ',');

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.quantity,
    required this.onChanged,
  });

  final Map<String, dynamic> product;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final price =
        double.tryParse(product['default_price']?.toString() ?? '') ?? 0;
    final unit = product['unit']?.toString() ?? 'szt.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name']?.toString() ?? 'Produkt',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${NumberFormat.currency(locale: 'pl_PL', symbol: 'zł').format(price)} / $unit',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
                ),
              ],
            ),
          ),
          _Stepper(value: quantity, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: WntColors.inputLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zmniejsz ilość',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 40),
            onPressed: value == 0 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Zwiększ ilość',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 40),
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 18, color: WntColors.brand),
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : const [];

int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

int? _defaultLocation(List<Map<String, dynamic>> locations) {
  if (locations.isEmpty) return null;
  final selected = locations.firstWhere(
    (location) => location['is_default'] == true,
    orElse: () => locations.first,
  );
  return _int(selected['id']);
}

String _locationLabel(Map<String, dynamic> location) {
  final name = location['name']?.toString().trim() ?? '';
  final address = location['address']?.toString().trim() ?? '';
  if (name.isEmpty) return address.isEmpty ? 'Lokalizacja' : address;
  if (address.isEmpty || address == name) return name;
  return '$name - $address';
}
