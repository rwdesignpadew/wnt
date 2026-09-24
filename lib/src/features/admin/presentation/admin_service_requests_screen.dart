import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/wnt_filter_tabs.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_bottom_navigation.dart';

class AdminServiceRequestsScreen extends ConsumerStatefulWidget {
  const AdminServiceRequestsScreen({super.key});

  @override
  ConsumerState<AdminServiceRequestsScreen> createState() =>
      _AdminServiceRequestsScreenState();
}

class _AdminServiceRequestsScreenState
    extends ConsumerState<AdminServiceRequestsScreen> {
  final _searchController = TextEditingController();
  String _status = 'open';
  late Future<Map<String, dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetch() => ref
      .read(adminRepositoryProvider)
      .serviceRequests(
        ref.read(authControllerProvider).session!.token,
        status: _status,
        search: _searchController.text,
      );

  void _reload() => setState(() => _request = _fetch());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Serwis')),
    bottomNavigationBar: adminBottomNavigation(context, ref),
    body: RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _request;
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          WntFilterTabs<String>(
            value: _status,
            items: const [
              WntFilterTab(value: 'open', label: 'Otwarte'),
              WntFilterTab(value: 'completed', label: 'Obsłużone'),
              WntFilterTab(value: 'all', label: 'Wszystkie'),
            ],
            onChanged: (value) {
              setState(() {
                _status = value;
                _request = _fetch();
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _reload(),
            decoration: InputDecoration(
              labelText: 'Szukaj klienta, lokalizacji lub WZ',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Szukaj',
                onPressed: _reload,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _ErrorCard(message: '${snapshot.error}', onRetry: _reload);
              }
              final rawItems = snapshot.data?['items'];
              final items = rawItems is List
                  ? rawItems
                        .whereType<Map>()
                        .map((item) => item.cast<String, dynamic>())
                        .toList()
                  : <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text('Brak serwisów dla wybranego filtra.'),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final item in items) ...[
                    _ServiceCard(
                      item: item,
                      onSettle: () => _settle(item),
                      onStatus: (status) => _changeStatus(item, status),
                      onDelete: () => _delete(item),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _settle(Map<String, dynamic> item) async {
    final controller = TextEditingController(
      text: _double(item['unit_price_net']) > 0
          ? _double(item['unit_price_net']).toStringAsFixed(2)
          : '',
    );
    final usesBalance = item['uses_balance'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(usesBalance ? 'Nalicz serwis do salda' : 'Wystaw Fakturę VAT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['client_name']} · ${item['equipment_name']}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cena serwisu netto',
                suffixText: 'zł',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(usesBalance ? 'Nalicz do salda' : 'Wystaw FV'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }
    final price = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    controller.dispose();
    if (price == null || price <= 0) {
      _message('Wpisz prawidłową cenę serwisu.', error: true);
      return;
    }
    try {
      final repository = ref.read(adminRepositoryProvider);
      final token = ref.read(authControllerProvider).session!.token;
      final response = usesBalance
          ? await repository.chargeServiceToBalance(token, _int(item['id']), price)
          : await repository.createFinalInvoice(
              token,
              _int(item['invoice_document_id']),
              servicePrices: {'${item['delivery_item_id']}': price},
            );
      if (!mounted) return;
      _message('${response['message'] ?? 'Serwis został rozliczony.'}');
      _reload();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  Future<void> _changeStatus(
    Map<String, dynamic> item,
    String status,
  ) async {
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .updateServiceRequestStatus(
            ref.read(authControllerProvider).session!.token,
            _int(item['id']),
            status,
          );
      if (!mounted) return;
      _message('${response['message'] ?? 'Status został zapisany.'}');
      _reload();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usunąć zgłoszenie?'),
        content: Text('${item['client_name']} · ${item['equipment_name']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .deleteServiceRequest(
            ref.read(authControllerProvider).session!.token,
            _int(item['id']),
          );
      if (!mounted) return;
      _message('${response['message'] ?? 'Zgłoszenie zostało usunięte.'}');
      _reload();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? WntColors.error : WntColors.success,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.item,
    required this.onSettle,
    required this.onStatus,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onSettle;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final settled = item['is_settled'] == true;
    final canSettle = item['can_settle'] == true;
    final status = '${item['status'] ?? ''}';
    final location = [
      item['location_name'],
      item['location_address'],
    ].where((value) => '${value ?? ''}'.trim().isNotEmpty).join(' · ');
    final document = '${item['document_number'] ?? ''}'.trim();
    final driver = '${item['driver_name'] ?? ''}'.trim();
    final notes = '${item['description'] ?? ''}'.trim();
    final color = status == 'new'
        ? WntColors.error
        : settled
        ? WntColors.success
        : WntColors.warning;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item['client_name'] ?? 'Klient'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: WntColors.ink,
                    ),
                  ),
                ),
                _StatusBadge(label: '${item['status_label'] ?? ''}', color: color),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${item['equipment_name'] ?? 'Serwis'} · ${_int(item['quantity'])} szt.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(location, style: const TextStyle(color: WntColors.muted)),
              ),
            if (document.isNotEmpty || driver.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  [
                    if (document.isNotEmpty) document,
                    if (driver.isNotEmpty) driver,
                  ].join(' · '),
                  style: const TextStyle(
                    color: WntColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text('Uwagi kierowcy: $notes'),
              ),
            if (settled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  item['is_balance_charged'] == true
                      ? 'Naliczono do salda: ${_money(item['balance_charge_amount'])}'
                      : 'Faktura VAT: ${item['invoice_number'] ?? 'wystawiona'}',
                  style: const TextStyle(
                    color: WntColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (!settled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canSettle)
                    Expanded(
                      child: FilledButton(
                        onPressed: onSettle,
                        child: Text(
                          item['uses_balance'] == true
                              ? 'Nalicz do salda'
                              : 'Wystaw Fakturę VAT',
                        ),
                      ),
                    )
                  else if (status == 'new')
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onStatus('accepted'),
                        child: const Text('Przyjmij'),
                      ),
                    )
                  else if (status == 'accepted' || status == 'planned')
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onStatus('completed'),
                        child: const Text('Zakończ'),
                      ),
                    ),
                  if (item['can_delete'] == true) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Usuń',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: WntColors.error),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: WntColors.error)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Spróbuj ponownie')),
        ],
      ),
    ),
  );
}

int _int(dynamic value) => int.tryParse('$value') ?? 0;
double _double(dynamic value) => double.tryParse('$value') ?? 0;
String _money(dynamic value) => '${_double(value).toStringAsFixed(2).replaceAll('.', ',')} zł';
