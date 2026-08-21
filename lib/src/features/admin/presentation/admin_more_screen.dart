import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/application/home_navigation_provider.dart';
import '../application/admin_providers.dart';
import 'admin_clients_screen.dart';
import 'admin_settings_edit_screen.dart';

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Więcej', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline, color: WntColors.brand),
              title: const Text('Klienci'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminClientsNestedScreen(),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.inventory_2_outlined,
                color: WntColors.brand,
              ),
              title: const Text('Produkty'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminProductsScreen()),
              ),
            ),
            const Divider(),
            for (final section in const [
              ('orders', 'Zamówienia', Icons.shopping_cart_outlined),
              ('drivers', 'Kierowcy', Icons.badge_outlined),
              ('regions', 'Regiony', Icons.map_outlined),
              (
                'sanitizations',
                'Sanityzacje',
                Icons.cleaning_services_outlined,
              ),
            ]) ...[
              ListTile(
                leading: Icon(section.$3, color: WntColors.brand),
                title: Text(section.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminOperationsScreen(
                      dataKey: section.$1,
                      title: section.$2,
                    ),
                  ),
                ),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Wyloguj się'),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    ],
  );
}

PreferredSizeWidget _adminNestedHeader(
  BuildContext context,
  WidgetRef ref,
  String section, {
  List<Widget> sectionActions = const [],
}) {
  final user = ref.watch(authControllerProvider).session!.user;
  return AppBar(
    automaticallyImplyLeading: false,
    title: Row(
      children: [
        Image.asset('assets/wnt_app.png', width: 36, height: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Woda na telefon'),
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      ...sectionActions,
      IconButton(
        tooltip: 'Wyloguj się',
        onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        icon: const Icon(Icons.logout_outlined),
      ),
      const SizedBox(width: 6),
    ],
  );
}

Widget _adminNestedNavigation(BuildContext context, WidgetRef ref) {
  const destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Start',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Trasy',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart),
      label: 'Zamówienia',
    ),
    NavigationDestination(
      icon: Icon(Icons.description_outlined),
      selectedIcon: Icon(Icons.description),
      label: 'Dokumenty',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz),
      selectedIcon: Icon(Icons.more_horiz),
      label: 'Więcej',
    ),
  ];
  return MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1,
    child: NavigationBar(
      selectedIndex: 4,
      destinations: destinations,
      onDestinationSelected: (index) {
        ref.read(homeNavigationIndexProvider.notifier).state = index;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    ),
  );
}

class AdminClientsNestedScreen extends ConsumerWidget {
  const AdminClientsNestedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: _adminNestedHeader(context, ref, 'Klienci'),
    bottomNavigationBar: _adminNestedNavigation(context, ref),
    body: const AdminClientsScreen(),
  );
}

class AdminOperationsScreen extends ConsumerWidget {
  const AdminOperationsScreen({
    required this.dataKey,
    required this.title,
    this.embedded = false,
    super.key,
  });

  final String dataKey;
  final String title;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: embedded ? null : _adminNestedHeader(context, ref, title),
    bottomNavigationBar: embedded ? null : _adminNestedNavigation(context, ref),
    floatingActionButton: embedded
        ? null
        : ['drivers', 'regions'].contains(dataKey)
        ? FloatingActionButton(
            tooltip: dataKey == 'drivers' ? 'Dodaj kierowcę' : 'Dodaj region',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminSettingsEditScreen(kind: dataKey),
                ),
              );
              ref.invalidate(adminOperationsProvider);
            },
            child: const Icon(Icons.add),
          )
        : null,
    body: ref
        .watch(adminOperationsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(adminOperationsProvider),
          ),
          data: (data) {
            final items = data[dataKey] is List
                ? (data[dataKey] as List)
                      .whereType<Map>()
                      .map((item) => item.cast<String, dynamic>())
                      .toList()
                : <Map<String, dynamic>>[];
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(adminOperationsProvider.future),
              child: items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'Brak pozycji',
                          message: 'W tej sekcji nie ma jeszcze danych.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final overdue =
                            dataKey == 'sanitizations' &&
                            item['status']?.toString() == 'overdue';
                        return Card(
                          color: overdue ? WntColors.errorSoft : null,
                          child: ListTile(
                            title: Text(item['title']?.toString() ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [item['subtitle'], item['meta']]
                                      .where(
                                        (value) =>
                                            value
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ==
                                            true,
                                      )
                                      .join('\n'),
                                ),
                                const SizedBox(height: 4),
                                _StatusBadge(
                                  status: item['status']?.toString() ?? '',
                                ),
                              ],
                            ),
                            trailing:
                                dataKey == 'sanitizations' &&
                                    [
                                      'planned',
                                      'overdue',
                                    ].contains(item['status']?.toString())
                                ? PopupMenuButton<String>(
                                    tooltip: 'Działania',
                                    onSelected: (action) => _sanitizationAction(
                                      context,
                                      ref,
                                      item,
                                      action,
                                    ),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'complete',
                                        child: Text('Oznacz jako wykonaną'),
                                      ),
                                      PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Anuluj sanityzację'),
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: dataKey == 'orders'
                                ? () async {
                                    await showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      builder: (_) => _OrderSheet(
                                        order: item,
                                        routes: data['route_options'] is List
                                            ? (data['route_options'] as List)
                                                  .whereType<Map>()
                                                  .map(
                                                    (route) => route
                                                        .cast<
                                                          String,
                                                          dynamic
                                                        >(),
                                                  )
                                                  .toList()
                                            : const [],
                                      ),
                                    );
                                    ref.invalidate(adminOperationsProvider);
                                  }
                                : ['drivers', 'regions'].contains(dataKey)
                                ? () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AdminSettingsEditScreen(
                                          kind: dataKey,
                                          item: item,
                                        ),
                                      ),
                                    );
                                    ref.invalidate(adminOperationsProvider);
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            );
          },
        ),
  );

  Future<void> _sanitizationAction(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    String action,
  ) async {
    final verb = action == 'complete' ? 'wykonaną' : 'anulowaną';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Oznaczyć sanityzację jako $verb?'),
        content: action == 'complete'
            ? const Text(
                'Data wykonania zostanie zapisana, a następny termin będzie wyliczony według interwału klienta.',
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Wróć'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Potwierdź'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      final response = action == 'complete'
          ? await repository.completeSanitization(token, _int(item['id']))
          : await repository.cancelSanitization(token, _int(item['id']));
      ref.invalidate(adminOperationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']?.toString() ?? 'Zapisano.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    }
  }
}

class _OrderSheet extends ConsumerStatefulWidget {
  const _OrderSheet({required this.order, required this.routes});
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> routes;

  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  late String status = '${widget.order['status'] ?? 'new'}';
  late int routeId = _int(widget.order['route_id']);
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      if (routeId != _int(widget.order['route_id'])) {
        await repository.assignOrderRoute(
          token,
          _int(widget.order['id']),
          routeId == 0 ? null : routeId,
        );
      }
      final resultingStatus = routeId > 0 ? 'planned' : status;
      if (resultingStatus != '${widget.order['status']}') {
        await repository.updateOrderStatus(
          token,
          _int(widget.order['id']),
          resultingStatus,
        );
      }
      if (mounted) Navigator.pop(context);
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
  Widget build(BuildContext context) {
    final items = widget.order['items'] is List
        ? (widget.order['items'] as List)
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList()
        : <Map<String, dynamic>>[];
    return FractionallySizedBox(
      heightFactor: .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.order['title'] ?? 'Zamówienie'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${widget.order['subtitle'] ?? ''} - ${widget.order['location'] ?? ''}',
                        style: const TextStyle(color: WntColors.muted),
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
                Text('${widget.order['address'] ?? ''}'),
                if ('${widget.order['preferred_delivery_date'] ?? ''}'
                    .isNotEmpty)
                  Text(
                    'Preferowana data: ${widget.order['preferred_delivery_date']}',
                  ),
                if ('${widget.order['notes'] ?? ''}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Uwagi: ${widget.order['notes']}'),
                ],
                const SizedBox(height: 16),
                Text(
                  'Produkty',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Card(
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        ListTile(
                          dense: true,
                          title: Text('${items[index]['name']}'),
                          trailing: Text(
                            '${items[index]['quantity']} ${items[index]['unit']}',
                          ),
                        ),
                        if (index < items.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: routeId,
                  decoration: const InputDecoration(labelText: 'Trasa'),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Nieprzypisane'),
                    ),
                    ...widget.routes.map(
                      (route) => DropdownMenuItem(
                        value: _int(route['id']),
                        child: Text(
                          '${route['date']} - ${route['name']} (${route['driver'] ?? 'bez kierowcy'})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    routeId = value ?? 0;
                    if (routeId > 0) {
                      status = 'planned';
                    } else if (status == 'planned') {
                      status = 'new';
                    }
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('Nowe')),
                    DropdownMenuItem(
                      value: 'accepted',
                      child: Text('Przyjęte'),
                    ),
                    DropdownMenuItem(
                      value: 'planned',
                      child: Text('Zaplanowane'),
                    ),
                    DropdownMenuItem(
                      value: 'in_delivery',
                      child: Text('W dostawie'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Zrealizowane'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Anulowane'),
                    ),
                  ],
                  onChanged: routeId > 0
                      ? null
                      : (value) => setState(() => status = value ?? 'new'),
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
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Zapisz obsługę zamówienia'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final overdue = status == 'overdue';
    final label = switch (status) {
      'new' => 'Nowe',
      'accepted' => 'Przyjęte',
      'planned' => 'Zaplanowane',
      'completed' => 'Wykonane',
      'overdue' => 'Po terminie',
      'missed' => 'Nie zastano',
      'cancelled' => 'Anulowane',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: overdue ? WntColors.errorSoft : WntColors.brandSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: overdue ? WntColors.error : WntColors.brand,
        ),
      ),
    );
  }
}

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});
  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  String _query = '';
  bool _active = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _adminNestedHeader(
      context,
      ref,
      'Produkty',
      sectionActions: [
        IconButton(
          tooltip: 'Dodaj produkt',
          icon: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminProductEditScreen()),
            );
            ref.invalidate(adminProductsProvider);
          },
        ),
      ],
    ),
    bottomNavigationBar: _adminNestedNavigation(context, ref),
    body: ref
        .watch(adminProductsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(adminProductsProvider),
          ),
          data: (all) {
            final byStatus = all
                .where(
                  (item) =>
                      (item['status']?.toString() == 'aktywny') == _active,
                )
                .toList();
            final items = _query.isEmpty
                ? byStatus
                : byStatus
                      .where(
                        (item) =>
                            item['title']?.toString().toLowerCase().contains(
                              _query.toLowerCase(),
                            ) ==
                            true,
                      )
                      .toList();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Aktywne')),
                      ButtonSegment(value: false, label: Text('Wyłączone')),
                    ],
                    selected: {_active},
                    onSelectionChanged: (value) =>
                        setState(() => _active = value.first),
                  );
                }
                if (index == 1) {
                  return TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Szukaj produktu',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  );
                }
                final product = items[index - 2];
                return Card(
                  child: ListTile(
                    title: Text(product['title']?.toString() ?? 'Produkt'),
                    subtitle: Text(
                      '${product['subtitle'] ?? ''} · ${product['meta'] ?? ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Działania',
                      onSelected: (action) => _productAction(product, action),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edytuj')),
                        PopupMenuItem(value: 'delete', child: Text('Usuń')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
  );

  Future<void> _productAction(
    Map<String, dynamic> product,
    String action,
  ) async {
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminProductEditScreen(id: _int(product['id'])),
        ),
      );
      ref.invalidate(adminProductsProvider);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć produkt?'),
        content: Text('Produkt „${product['title'] ?? ''}” zostanie usunięty.'),
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
      await ref
          .read(adminRepositoryProvider)
          .deleteProduct(token, _int(product['id']));
      ref.invalidate(adminProductsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class AdminProductEditScreen extends ConsumerStatefulWidget {
  const AdminProductEditScreen({this.id, super.key});
  final int? id;
  @override
  ConsumerState<AdminProductEditScreen> createState() =>
      _AdminProductEditScreenState();
}

class _AdminProductEditScreenState
    extends ConsumerState<AdminProductEditScreen> {
  Map<String, dynamic>? _product;
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _vat = TextEditingController();
  final _stock = TextEditingController();
  final _minimum = TextEditingController();
  bool _active = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    if (widget.id == null) {
      _product = {'kind': 'product', 'unit': 'szt.'};
      _vat.text = '23';
      _stock.text = '0';
      _minimum.text = '0';
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _price, _vat, _stock, _minimum]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .product(token, widget.id!);
      _product = _map(response['product']) ?? {};
      _name.text = '${_product?['name'] ?? ''}';
      _price.text = '${_product?['default_price'] ?? ''}';
      _vat.text = '${_product?['vat_rate'] ?? ''}';
      _stock.text = '${_product?['stock'] ?? 0}';
      _minimum.text = '${_product?['minimum_stock'] ?? 0}';
      _active = _product?['is_active'] == true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final payload = {
        'name': _name.text.trim(),
        'kind': _product?['kind'] ?? 'product',
        'unit': _product?['unit'] ?? 'szt.',
        'default_price': double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
        'vat_rate': double.tryParse(_vat.text.replaceAll(',', '.')) ?? 23,
        'stock': int.tryParse(_stock.text) ?? 0,
        'minimum_stock': int.tryParse(_minimum.text) ?? 0,
        'is_active': _active,
      };
      if (_name.text.trim().isEmpty) {
        throw Exception('Wpisz nazwę produktu.');
      }
      if (widget.id == null) {
        await ref.read(adminRepositoryProvider).createProduct(token, payload);
      } else {
        await ref
            .read(adminRepositoryProvider)
            .updateProduct(token, widget.id!, payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _adminNestedHeader(
      context,
      ref,
      widget.id == null ? 'Nowy produkt' : 'Edytuj produkt',
    ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _product == null || _saving ? null : _save,
                child: Text(_saving ? 'Zapisywanie...' : 'Zapisz produkt'),
              ),
            ),
          ),
        ),
        _adminNestedNavigation(context, ref),
      ],
    ),
    body: _product == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nazwa'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cena netto',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _vat,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'VAT %'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _minimum,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stan minimalny',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Produkt aktywny'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
  );
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : null;
int _int(dynamic value) => int.tryParse('$value') ?? 0;
