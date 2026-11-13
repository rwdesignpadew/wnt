import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/wnt_filter_tabs.dart';
import '../../../shared/widgets/wnt_searchable_select.dart';
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

  void _reload() {
    ref.invalidate(adminSummaryProvider);
    setState(() => _request = _fetch());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Serwis'),
      actions: [
        IconButton(
          tooltip: 'Nowy serwis',
          onPressed: _createService,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
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
                return _ErrorCard(
                  message: '${snapshot.error}',
                  onRetry: _reload,
                );
              }
              final rawItems = snapshot.data?['items'];
              final items = rawItems is List
                  ? rawItems
                        .whereType<Map>()
                        .map((item) => item.cast<String, dynamic>())
                        .toList()
                  : <Map<String, dynamic>>[];
              final routes = _maps(snapshot.data?['routes']);
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
                      onAssignRoute:
                          item['is_free'] == true &&
                              _int(item['route_id']) < 1 &&
                              ![
                                'completed',
                                'cancelled',
                              ].contains(item['status'])
                          ? () => _assignRoute(item, routes)
                          : null,
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

  Future<void> _createService() async {
    try {
      final data = await _request;
      if (!mounted) return;
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CreateServiceSheet(clients: _maps(data['clients'])),
      );
      if (created == true) _reload();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  Future<void> _assignRoute(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> routes,
  ) async {
    int? routeId;
    final availableRoutes = routes
        .where((route) => _int(route['driver_id']) > 0)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Przypisz serwis do trasy'),
          content: availableRoutes.isEmpty
              ? const Text(
                  'Brak aktywnej trasy z przypisanym kierowcą. Najpierw utwórz trasę lub przypisz do niej kierowcę.',
                )
              : DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: routeId,
                  decoration: const InputDecoration(labelText: 'Trasa'),
                  items: availableRoutes
                      .map(
                        (route) => DropdownMenuItem<int>(
                          value: _int(route['id']),
                          child: Text(
                            '${route['date']} · ${route['name']} · ${route['driver_name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => routeId = value),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Anuluj'),
            ),
            if (availableRoutes.isNotEmpty)
              FilledButton(
                onPressed: routeId == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Przypisz'),
              ),
          ],
        ),
      ),
    );
    if (confirmed != true || routeId == null || !mounted) return;
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .assignServiceRequestRoute(
            ref.read(authControllerProvider).session!.token,
            _int(item['id']),
            routeId!,
          );
      if (!mounted) return;
      _message(
        '${response['message'] ?? 'Serwis został przypisany do trasy.'}',
      );
      _reload();
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

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
        title: Text(
          usesBalance ? 'Nalicz serwis do salda' : 'Wystaw Fakturę VAT',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['client_name']} · ${item['equipment_name']}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
          ? await repository.chargeServiceToBalance(
              token,
              _int(item['id']),
              price,
            )
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

  Future<void> _changeStatus(Map<String, dynamic> item, String status) async {
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

class _CreateServiceSheet extends ConsumerStatefulWidget {
  const _CreateServiceSheet({required this.clients});

  final List<Map<String, dynamic>> clients;

  @override
  ConsumerState<_CreateServiceSheet> createState() =>
      _CreateServiceSheetState();
}

class _CreateServiceSheetState extends ConsumerState<_CreateServiceSheet> {
  final description = TextEditingController();
  final notes = TextEditingController();
  int? clientId;
  int? locationId;
  bool saving = false;

  Map<String, dynamic>? get client {
    for (final item in widget.clients) {
      if (_int(item['id']) == clientId) return item;
    }
    return null;
  }

  List<Map<String, dynamic>> get locations => _maps(client?['locations']);

  @override
  void dispose() {
    description.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pickClient() async {
    final selected = await showWntSearchPicker<Map<String, dynamic>>(
      context: context,
      title: 'Wybierz klienta',
      searchHint: 'Szukaj klienta lub lokalizacji',
      items: widget.clients,
      selected: client,
      titleFor: (item) => '${item['name'] ?? ''}',
      subtitleFor: (item) => _maps(item['locations'])
          .map((location) => '${location['name']} ${location['address'] ?? ''}')
          .join(' · '),
      searchTextFor: (item) => [
        item['name'],
        ..._maps(
          item['locations'],
        ).expand((location) => [location['name'], location['address']]),
      ].join(' '),
    );
    if (selected == null || !mounted) return;
    final clientLocations = _maps(selected['locations']);
    final defaultLocation = clientLocations.firstWhere(
      (location) => location['is_default'] == true,
      orElse: () => clientLocations.isEmpty ? const {} : clientLocations.first,
    );
    setState(() {
      clientId = _int(selected['id']);
      locationId = _int(defaultLocation['id']) > 0
          ? _int(defaultLocation['id'])
          : null;
    });
  }

  Future<void> save() async {
    if (clientId == null || description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz klienta i opisz serwis.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .createServiceRequest(
            ref.read(authControllerProvider).session!.token,
            {
              'client_id': clientId,
              if (locationId != null) 'client_location_id': locationId,
              'description': description.text.trim(),
              if (notes.text.trim().isNotEmpty)
                'admin_notes': notes.text.trim(),
            },
          );
      ref.invalidate(adminSummaryProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message'] ?? 'Serwis utworzono.'}'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: Column(
      children: [
        ListTile(
          title: const Text(
            'Nowy serwis',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('Trasę i kierowcę przypiszesz później.'),
          trailing: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              WntSearchableSelectField(
                label: 'Klient',
                value: client?['name']?.toString(),
                hintText: 'Wyszukaj klienta',
                onTap: widget.clients.isEmpty ? null : pickClient,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: locationId,
                decoration: const InputDecoration(labelText: 'Lokalizacja'),
                items: [
                  if (locations.isEmpty)
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Główna lokalizacja'),
                    ),
                  ...locations.map(
                    (location) => DropdownMenuItem<int?>(
                      value: _int(location['id']),
                      child: Text(
                        '${location['name']} · ${location['address'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: clientId == null
                    ? null
                    : (value) => setState(() => locationId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Co kierowca ma zrobić',
                  hintText: 'Np. wymiana uszkodzonego kranika',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Uwagi dla kierowcy (opcjonalnie)',
                ),
              ),
              const Text(
                'Zgłoszenie zostanie zapisane bez trasy i kierowcy. Nie trafi na WZ ani fakturę.',
                style: TextStyle(color: WntColors.muted),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Utwórz serwis'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.item,
    required this.onAssignRoute,
    required this.onSettle,
    required this.onStatus,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback? onAssignRoute;
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
                _StatusBadge(
                  label: '${item['status_label'] ?? ''}',
                  color: color,
                ),
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
                child: Text(
                  location,
                  style: const TextStyle(color: WntColors.muted),
                ),
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
              if (onAssignRoute != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAssignRoute,
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Przypisz do trasy'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
                      icon: const Icon(
                        Icons.delete_outline,
                        color: WntColors.error,
                      ),
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
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    ),
  );
}

int _int(dynamic value) => int.tryParse('$value') ?? 0;
double _double(dynamic value) => double.tryParse('$value') ?? 0;
List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : <Map<String, dynamic>>[];
String _money(dynamic value) =>
    '${_double(value).toStringAsFixed(2).replaceAll('.', ',')} zł';
