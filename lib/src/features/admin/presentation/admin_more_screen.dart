import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/wnt_searchable_select.dart';
import '../../../shared/widgets/wnt_filter_tabs.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/application/home_navigation_provider.dart';
import '../../documents/presentation/pdf_document_screen.dart';
import '../application/admin_providers.dart';
import 'admin_clients_screen.dart';
import 'admin_administrators_screen.dart';
import 'admin_driver_statistics_screen.dart';
import 'admin_settings_edit_screen.dart';
import 'admin_management_screens.dart';
import 'admin_service_requests_screen.dart';

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminSummaryProvider).valueOrNull;
    final canSeeService = ref
        .watch(authControllerProvider)
        .session!
        .user
        .hasAdminPermission('service');
    final openServices = canSeeService
        ? _adminAlertCount(summary, 'service')
        : 0;
    final newOrders = _adminAlertCount(summary, 'orders');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Więcej', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: WntColors.brand,
                ),
                title: const Text('Salda klientów'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminBalancesScreen(),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.water_drop_outlined,
                  color: WntColors.brand,
                ),
                title: const Text('Dzierżawy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminRentalsScreen()),
                ),
              ),
              const Divider(),
              if (canSeeService) ...[
                ListTile(
                  leading: const Icon(
                    Icons.build_outlined,
                    color: WntColors.brand,
                  ),
                  title: const Text('Serwis'),
                  subtitle: const Text('Zgłoszenia z WZ i od klientów'),
                  trailing: _notificationTrailing(openServices),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminServiceRequestsScreen(),
                    ),
                  ),
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(
                  Icons.sticky_note_2_outlined,
                  color: WntColors.brand,
                ),
                title: const Text('Uwagi do tras'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminRouteNotesScreen(),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.local_shipping_outlined,
                  color: WntColors.brand,
                ),
                title: const Text('Przełącz na tryb kierowcy'),
                trailing: const Icon(Icons.swap_horiz),
                onTap: () => _selectDriverMode(context, ref),
              ),
              const Divider(),
              if (ref
                  .watch(authControllerProvider)
                  .session!
                  .user
                  .hasAdminPermission('clients')) ...[
                ListTile(
                  leading: const Icon(
                    Icons.people_outline,
                    color: WntColors.brand,
                  ),
                  title: const Text('Klienci'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminClientsNestedScreen(),
                    ),
                  ),
                ),
                const Divider(),
              ],
              if (ref
                  .watch(authControllerProvider)
                  .session!
                  .user
                  .hasAdminPermission('administrators')) ...[
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: WntColors.brand,
                  ),
                  title: const Text('Administratorzy i uprawnienia'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminAdministratorsNestedScreen(),
                    ),
                  ),
                ),
                const Divider(),
              ],
              if (ref
                  .watch(authControllerProvider)
                  .session!
                  .user
                  .hasAdminPermission('drivers')) ...[
                ListTile(
                  leading: const Icon(
                    Icons.query_stats_outlined,
                    color: WntColors.brand,
                  ),
                  title: const Text('Statystyki kierowców'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminDriverStatisticsNestedScreen(),
                    ),
                  ),
                ),
                const Divider(),
              ],
              if (ref
                  .watch(authControllerProvider)
                  .session!
                  .user
                  .hasAdminPermission('products')) ...[
                ListTile(
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: WntColors.brand,
                  ),
                  title: const Text('Produkty'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminProductsScreen(),
                    ),
                  ),
                ),
                const Divider(),
              ],
              for (final section in const [
                ('orders', 'Zamówienia', Icons.shopping_cart_outlined),
                ('drivers', 'Kierowcy', Icons.badge_outlined),
                ('regions', 'Regiony', Icons.map_outlined),
                (
                  'sanitizations',
                  'Sanityzacje',
                  Icons.cleaning_services_outlined,
                ),
              ])
                if (ref
                    .watch(authControllerProvider)
                    .session!
                    .user
                    .hasAdminPermission(section.$1)) ...[
                  ListTile(
                    leading: Icon(section.$3, color: WntColors.brand),
                    title: Text(section.$2),
                    trailing: _notificationTrailing(
                      section.$1 == 'orders' ? newOrders : 0,
                    ),
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
}

Widget _notificationTrailing(int count) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (count > 0) ...[
      Badge(
        backgroundColor: WntColors.error,
        label: Text(count > 99 ? '99+' : '$count'),
      ),
      const SizedBox(width: 8),
    ],
    const Icon(Icons.chevron_right),
  ],
);

int _adminAlertCount(Map<String, dynamic>? summary, String kind) {
  final alerts = summary?['alerts'];
  if (alerts is! List) return 0;
  for (final raw in alerts.whereType<Map>()) {
    if (raw['kind']?.toString() == kind) {
      return int.tryParse('${raw['value']}') ?? 0;
    }
  }
  return 0;
}

Future<void> _selectDriverMode(BuildContext context, WidgetRef ref) async {
  final data = await ref.read(adminOperationsProvider.future);
  if (!context.mounted) return;
  final drivers = data['drivers'] is List
      ? (data['drivers'] as List).whereType<Map>().toList()
      : const <Map>[];
  final id = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Wybierz konto kierowcy')),
          ...drivers.map(
            (driver) => ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text('${driver['title'] ?? ''}'),
              subtitle: Text('${driver['subtitle'] ?? ''}'),
              onTap: () =>
                  Navigator.pop(context, int.tryParse('${driver['id']}')),
            ),
          ),
        ],
      ),
    ),
  );
  if (id != null) {
    await ref.read(authControllerProvider.notifier).switchToDriver(id);
  }
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

class AdminDriverStatisticsNestedScreen extends ConsumerWidget {
  const AdminDriverStatisticsNestedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: _adminNestedHeader(context, ref, 'Statystyki kierowców'),
    bottomNavigationBar: _adminNestedNavigation(context, ref),
    body: const AdminDriverStatisticsScreen(),
  );
}

class AdminAdministratorsNestedScreen extends ConsumerWidget {
  const AdminAdministratorsNestedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: _adminNestedHeader(context, ref, 'Administratorzy'),
    bottomNavigationBar: _adminNestedNavigation(context, ref),
    body: const AdminAdministratorsScreen(embedded: true),
  );
}

class AdminOperationsScreen extends ConsumerWidget {
  const AdminOperationsScreen({
    required this.dataKey,
    required this.title,
    this.embedded = false,
    this.initialSanitizationStatus = 'open',
    super.key,
  });

  final String dataKey;
  final String title;
  final bool embedded;
  final String initialSanitizationStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: embedded ? null : _adminNestedHeader(context, ref, title),
    bottomNavigationBar: embedded ? null : _adminNestedNavigation(context, ref),
    floatingActionButton: dataKey == 'orders'
        ? FloatingActionButton.extended(
            tooltip: 'Nowe zamówienie',
            onPressed: () async {
              final data = await ref.read(adminOperationsProvider.future);
              if (!context.mounted) return;
              await _openOrderCreator(context, ref, data);
            },
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: const Text('Nowe'),
          )
        : embedded
        ? null
        : ['drivers', 'regions', 'sanitizations'].contains(dataKey)
        ? FloatingActionButton(
            tooltip: dataKey == 'drivers'
                ? 'Dodaj kierowcę'
                : dataKey == 'regions'
                ? 'Dodaj region'
                : 'Zaplanuj sanityzację',
            onPressed: () async {
              if (dataKey == 'sanitizations') {
                final data = await ref.read(adminOperationsProvider.future);
                if (!context.mounted) return;
                await _openSanitizationEditor(context, ref, data);
              } else {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminSettingsEditScreen(kind: dataKey),
                  ),
                );
              }
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
            if (dataKey == 'sanitizations') {
              return _AdminSanitizationsContent(
                data: data,
                items: items,
                initialStatus: initialSanitizationStatus,
                onRefresh: () async =>
                    ref.refresh(adminOperationsProvider.future),
                onEdit: (item) =>
                    _openSanitizationEditor(context, ref, data, item: item),
                onAction: (item, action) =>
                    _sanitizationAction(context, ref, item, action),
              );
            }
            if (dataKey == 'orders') {
              return _AdminOrdersContent(
                data: data,
                items: items,
                onRefresh: () async =>
                    ref.refresh(adminOperationsProvider.future),
              );
            }
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
                        final overdueOrder =
                            dataKey == 'orders' && item['is_overdue'] == true;
                        final newOrder =
                            dataKey == 'orders' &&
                            item['status']?.toString() == 'new';
                        return Card(
                          color: overdue
                              ? WntColors.errorSoft
                              : overdueOrder
                              ? WntColors.warningSoft
                              : newOrder
                              ? WntColors.errorSoft
                              : null,
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
                                  status:
                                      item['display_status']?.toString() ??
                                      item['status']?.toString() ??
                                      '',
                                ),
                              ],
                            ),
                            trailing: dataKey == 'sanitizations'
                                ? PopupMenuButton<String>(
                                    tooltip: 'Działania',
                                    onSelected: (action) => _sanitizationAction(
                                      context,
                                      ref,
                                      item,
                                      action,
                                    ),
                                    itemBuilder: (_) => [
                                      if (item['status'] == 'overdue' &&
                                          item['route_is_upcoming'] != true)
                                        const PopupMenuItem(
                                          value: 'plan_route',
                                          child: Text('Dodaj zaległą do trasy'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Szczegóły i edycja'),
                                      ),
                                      if ([
                                        'planned',
                                        'overdue',
                                        'in_progress',
                                      ].contains(
                                        item['status']?.toString(),
                                      )) ...const [
                                        PopupMenuItem(
                                          value: 'complete',
                                          child: Text('Oznacz jako wykonaną'),
                                        ),
                                        PopupMenuItem(
                                          value: 'reschedule',
                                          child: Text('Nie zastano - przełóż'),
                                        ),
                                        PopupMenuItem(
                                          value: 'cancel',
                                          child: Text('Anuluj sanityzację'),
                                        ),
                                      ],
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Usuń'),
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
                                        documents: _maps(
                                          data['completed_order_documents'],
                                        ),
                                        clients: _maps(data['order_clients']),
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
                                  }
                                : dataKey == 'sanitizations'
                                ? () => _openSanitizationEditor(
                                    context,
                                    ref,
                                    data,
                                    item: item,
                                  )
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
    if (action == 'plan_route') {
      final data = await ref.read(adminOperationsProvider.future);
      if (context.mounted) {
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _SanitizationRouteSheet(item: item, data: data),
        );
        ref.invalidate(adminOperationsProvider);
        ref.invalidate(adminRoutesProvider);
      }
      return;
    }
    if (action == 'edit') {
      final data = await ref.read(adminOperationsProvider.future);
      if (context.mounted) {
        await _openSanitizationEditor(context, ref, data, item: item);
      }
      return;
    }
    final notes = TextEditingController();
    final correctionReason = TextEditingController();
    final interval = TextEditingController(
      text:
          '${_int(item['next_interval_days']) == 0 ? 180 : _int(item['next_interval_days'])}',
    );
    final taskEquipment = (item['task_equipment_units'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
    final selectableEquipment = taskEquipment
        .where((unit) => unit['selectable'] == true)
        .toList();
    final selectedEquipmentKeys = <String>{
      for (final unit in selectableEquipment) '${unit['key']}',
    };
    DateTime rescheduled = DateTime.now().add(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(switch (action) {
            'complete' => 'Sanityzacja wykonana',
            'correct' => 'Korekta wykonanej sanityzacji',
            'reschedule' => 'Nie zastano - przełóż',
            'delete' => 'Usunąć sanityzację?',
            _ => 'Anulować sanityzację?',
          }),
          content: action == 'delete'
              ? const Text('Tej operacji nie można cofnąć.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if ({'complete', 'correct'}.contains(action)) ...[
                        Text(
                          'Wybierz rzeczywiście wykonany sprzęt: ${selectedEquipmentKeys.length} z ${selectableEquipment.length}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (taskEquipment.isEmpty)
                          const Text(
                            'Brak sprzętu przypisanego do tego zadania. Odśwież dane lub popraw cykl na panelu web.',
                            style: TextStyle(color: WntColors.error),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                for (final unit in taskEquipment)
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: selectedEquipmentKeys.contains(
                                      '${unit['key']}',
                                    ),
                                    onChanged: unit['selectable'] == true
                                        ? (selected) => setDialogState(() {
                                            final key = '${unit['key']}';
                                            if (selected == true) {
                                              selectedEquipmentKeys.add(key);
                                            } else {
                                              selectedEquipmentKeys.remove(key);
                                            }
                                          })
                                        : null,
                                    title: Text(
                                      '${unit['label'] ?? unit['equipment_name'] ?? 'Urządzenie'}',
                                    ),
                                    subtitle:
                                        unit['selection_state'] == 'completed'
                                        ? const Text('Wykonana')
                                        : unit['selection_state'] ==
                                              'outside_task'
                                        ? const Text('Poza tym zadaniem')
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                      ],
                      if ({'complete', 'correct'}.contains(action))
                        const SizedBox(height: 12),
                      if (action == 'correct') ...[
                        TextField(
                          controller: correctionReason,
                          maxLines: 3,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Powód korekty WZ',
                            helperText: item['correction_source_number'] == null
                                ? null
                                : 'Korekta do ${item['correction_source_number']}',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if ({'complete', 'correct'}.contains(action))
                        TextField(
                          controller: interval,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Kolejna sanityzacja za ile dni',
                          ),
                        ),
                      if (action == 'reschedule')
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Nowy termin'),
                          subtitle: Text(_isoDate(rescheduled)),
                          trailing: const Icon(Icons.calendar_month_outlined),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: rescheduled,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => rescheduled = picked);
                            }
                          },
                        ),
                      if (action != 'delete')
                        TextField(
                          controller: notes,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: {'complete', 'correct'}.contains(action)
                                ? 'Uwagi po wykonaniu'
                                : 'Powód / uwagi',
                          ),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Wróć'),
            ),
            FilledButton(
              onPressed:
                  ({'complete', 'correct'}.contains(action) &&
                          selectedEquipmentKeys.isEmpty) ||
                      (action == 'correct' &&
                          correctionReason.text.trim().length < 3)
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Potwierdź'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      final response = switch (action) {
        'complete' => await repository.completeSanitization(
          token,
          _int(item['id']),
          intervalDays: _int(interval.text) == 0 ? 180 : _int(interval.text),
          completedDispenserCount: selectedEquipmentKeys.length,
          equipmentUnits: selectedEquipmentKeys.toList(),
          resultNotes: notes.text.trim(),
        ),
        'correct' => await repository.correctSanitization(
          token,
          _int(item['correction_target_id'] ?? item['id']),
          correctionReason: correctionReason.text.trim(),
          equipmentUnits: selectedEquipmentKeys.toList(),
          intervalDays: _int(interval.text) == 0 ? 180 : _int(interval.text),
          resultNotes: notes.text.trim(),
        ),
        'reschedule' => await repository.rescheduleSanitization(
          token,
          _int(item['id']),
          _isoDate(rescheduled),
          resultNotes: notes.text.trim(),
        ),
        'delete' => await repository.deleteSanitization(
          token,
          _int(item['id']),
        ),
        _ => await repository.cancelSanitization(
          token,
          _int(item['id']),
          resultNotes: notes.text.trim(),
        ),
      };
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

class _AdminSanitizationsContent extends StatefulWidget {
  const _AdminSanitizationsContent({
    required this.data,
    required this.items,
    required this.initialStatus,
    required this.onRefresh,
    required this.onEdit,
    required this.onAction,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> items;
  final String initialStatus;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic> item) onEdit;
  final Future<void> Function(Map<String, dynamic> item, String action)
  onAction;

  @override
  State<_AdminSanitizationsContent> createState() =>
      _AdminSanitizationsContentState();
}

class _AdminSanitizationsContentState
    extends State<_AdminSanitizationsContent> {
  final TextEditingController _search = TextEditingController();
  late String _status;
  String _kind = 'all';
  String _due = 'all';
  int? _clientId;
  int? _driverId;
  bool _filtersVisible = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _activeFilterCount => [
    if (_status != 'open') _status,
    if (_kind != 'all') _kind,
    if (_due != 'all') _due,
    if (_clientId != null) 'client',
    if (_driverId != null) 'driver',
  ].length;

  List<MapEntry<int, String>> _options(String idKey, String nameKey) {
    final values = <int, String>{};
    for (final item in widget.items) {
      final id = _int(item[idKey]);
      final name = item[nameKey]?.toString().trim() ?? '';
      if (id > 0 && name.isNotEmpty) values[id] = name;
    }
    final options = values.entries.toList();
    options.sort(
      (left, right) =>
          left.value.toLowerCase().compareTo(right.value.toLowerCase()),
    );
    return options;
  }

  bool _matches(Map<String, dynamic> item) {
    final query = _search.text.trim().toLowerCase();
    final searchable = [
      item['client_name'],
      item['location_name'],
      item['driver_name'],
      item['route_name'],
      item['subtitle'],
      item['meta'],
      item['notes'],
    ].where((value) => value != null).join(' ').toLowerCase();
    if (query.isNotEmpty && !searchable.contains(query)) return false;

    final status = item['status']?.toString() ?? '';
    if (_status == 'open' &&
        !{'planned', 'overdue', 'in_progress'}.contains(status)) {
      return false;
    }
    if (_status != 'open' && _status != 'all' && status != _status) {
      return false;
    }
    final onRequest = item['is_on_request'] == true;
    if (_kind == 'regular' && onRequest) return false;
    if (_kind == 'on_request' && !onRequest) return false;
    if (_clientId != null && _int(item['client_id']) != _clientId) return false;
    if (_driverId != null && _int(item['driver_id']) != _driverId) return false;

    if (_due != 'all') {
      final scheduled = DateTime.tryParse(
        item['scheduled_date']?.toString() ?? '',
      );
      if (scheduled == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final date = DateTime(scheduled.year, scheduled.month, scheduled.day);
      if (_due == 'today' && date != today) return false;
      final days = _due == 'next_7' ? 7 : 30;
      if (_due != 'today' &&
          (date.isBefore(today) ||
              date.isAfter(today.add(Duration(days: days))))) {
        return false;
      }
    }
    return true;
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _status = 'open';
      _kind = 'all';
      _due = 'all';
      _clientId = null;
      _driverId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.data['sanitization_summary'] is Map
        ? (widget.data['sanitization_summary'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final filtered = widget.items.where(_matches).toList();
    final clients = _options('client_id', 'client_name');
    final drivers = _options('driver_id', 'driver_name');

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _SanitizationStatistics(summary: summary),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _quickStatusButton('Otwarte', 'open')),
              const SizedBox(width: 8),
              Expanded(child: _quickStatusButton('Wykonane', 'completed')),
              const SizedBox(width: 8),
              Expanded(child: _quickStatusButton('Wszystkie', 'all')),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Klient, lokalizacja lub kierowca',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Wyczyść wyszukiwanie',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              );
              final filterButton = OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _filtersVisible = !_filtersVisible),
                icon: const Icon(Icons.tune),
                label: Text(
                  _activeFilterCount == 0
                      ? 'Filtry'
                      : 'Filtry ($_activeFilterCount)',
                ),
              );
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    filterButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  filterButton,
                ],
              );
            },
          ),
          if (_filtersVisible) ...[
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _SanitizationDropdown(
                      label: 'Status',
                      value: _status,
                      options: const {
                        'open': 'Wszystkie bieżące',
                        'planned': 'Zaplanowane',
                        'overdue': 'Po terminie',
                        'in_progress': 'Do dokończenia',
                        'completed': 'Wykonane',
                        'partial': 'Częściowo wykonane',
                        'missed': 'Nie było klienta',
                        'cancelled': 'Anulowane',
                        'all': 'Wszystkie',
                      },
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'open'),
                    ),
                    const SizedBox(height: 10),
                    _SanitizationDropdown(
                      label: 'Rodzaj',
                      value: _kind,
                      options: const {
                        'all': 'Wszystkie',
                        'regular': 'Regularne',
                        'on_request': 'Na żądanie',
                      },
                      onChanged: (value) =>
                          setState(() => _kind = value ?? 'all'),
                    ),
                    const SizedBox(height: 10),
                    _SanitizationDropdown(
                      label: 'Termin',
                      value: _due,
                      options: const {
                        'all': 'Dowolny',
                        'today': 'Dzisiaj',
                        'next_7': 'Najbliższe 7 dni',
                        'next_30': 'Najbliższe 30 dni',
                      },
                      onChanged: (value) =>
                          setState(() => _due = value ?? 'all'),
                    ),
                    const SizedBox(height: 10),
                    _SanitizationSearchFilter(
                      label: 'Klient',
                      hint: 'Wszyscy klienci',
                      searchHint: 'Wpisz nazwę klienta',
                      options: clients,
                      selectedId: _clientId,
                      onChanged: (value) => setState(() => _clientId = value),
                    ),
                    const SizedBox(height: 10),
                    _SanitizationSearchFilter(
                      label: 'Kierowca',
                      hint: 'Wszyscy kierowcy',
                      searchHint: 'Wpisz nazwę kierowcy',
                      options: drivers,
                      selectedId: _driverId,
                      onChanged: (value) => setState(() => _driverId = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: TextButton.icon(
                            onPressed:
                                _activeFilterCount == 0 && _search.text.isEmpty
                                ? null
                                : _clearFilters,
                            icon: const Icon(Icons.filter_alt_off),
                            label: const Text('Wyczyść filtry'),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _filtersVisible = false),
                          child: const Text('Zwiń'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Wyświetlane: ${filtered.length} z ${widget.items.length}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.cleaning_services_outlined,
              title: 'Brak sanityzacji',
              message: 'Brak sanityzacji pasujących do wybranych filtrów.',
            )
          else
            for (final item in filtered) ...[
              _sanitizationCard(item),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _sanitizationCard(Map<String, dynamic> item) {
    final overdue = item['status']?.toString() == 'overdue';
    final resultNotes = '${item['result_notes'] ?? ''}'.trim();
    final documentNumber = '${item['document_number'] ?? ''}'.trim();
    return Card(
      color: overdue ? WntColors.errorSoft : null,
      child: ListTile(
        title: Text(item['title']?.toString() ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [item['subtitle'], item['meta']]
                  .where((value) => value?.toString().trim().isNotEmpty == true)
                  .join('\n'),
            ),
            const SizedBox(height: 4),
            _StatusBadge(status: item['status']?.toString() ?? ''),
            if (documentNumber.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'WZ: $documentNumber',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WntColors.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (resultNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WntColors.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: WntColors.brand.withValues(alpha: .25),
                  ),
                ),
                child: Text('Uwagi kierowcy / wykonania:\n$resultNotes'),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Działania',
          onSelected: (action) => widget.onAction(item, action),
          itemBuilder: (_) => [
            if ({'overdue', 'in_progress'}.contains(item['status']) &&
                item['route_is_upcoming'] != true)
              const PopupMenuItem(
                value: 'plan_route',
                child: Text('Dodaj do trasy'),
              ),
            if (item['can_edit_cycle'] == true)
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edytuj cykl i sprzęt'),
              ),
            if (item['can_correct'] == true)
              const PopupMenuItem(
                value: 'correct',
                child: Text('Skoryguj brakującą część WZ'),
              ),
            if ([
                  'planned',
                  'overdue',
                  'in_progress',
                ].contains(item['status']?.toString()) &&
                item['can_correct'] != true) ...const [
              PopupMenuItem(
                value: 'complete',
                child: Text('Oznacz jako wykonaną'),
              ),
              PopupMenuItem(
                value: 'reschedule',
                child: Text('Nie zastano - przełóż'),
              ),
              PopupMenuItem(value: 'cancel', child: Text('Anuluj sanityzację')),
            ],
            const PopupMenuItem(value: 'delete', child: Text('Usuń')),
          ],
        ),
        onTap: item['can_edit_cycle'] == true
            ? () => widget.onEdit(item)
            : null,
      ),
    );
  }

  Widget _quickStatusButton(String label, String value) {
    final selected =
        _status == value ||
        (value == 'open' &&
            {'planned', 'overdue', 'in_progress'}.contains(_status));
    return OutlinedButton(
      onPressed: () => setState(() => _status = value),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : WntColors.text,
        backgroundColor: selected ? WntColors.brand : Colors.white,
        side: BorderSide(
          color: selected ? WntColors.brand : WntColors.inputLine,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SanitizationStatistics extends StatelessWidget {
  const _SanitizationStatistics({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String)>[
      ('Po terminie', '${_int(summary['overdue'])}'),
      ('Na dzisiaj', '${_int(summary['today'])}'),
      ('Wszystkie otwarte', '${_int(summary['open'])}'),
      ('Na żądanie', '${_int(summary['on_request'])}'),
      ('Do dokończenia', '${_int(summary['in_progress'])}'),
      ('Wykonane w miesiącu', '${_int(summary['completed_month'])}'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tile.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tile.$2,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SanitizationDropdown extends StatelessWidget {
  const _SanitizationDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (option) => DropdownMenuItem(
            value: option.key,
            child: Text(option.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

class _SanitizationSearchFilter extends StatelessWidget {
  const _SanitizationSearchFilter({
    required this.label,
    required this.hint,
    required this.searchHint,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final String searchHint;
  final List<MapEntry<int, String>> options;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    MapEntry<int, String>? selected;
    for (final option in options) {
      if (option.key == selectedId) selected = option;
    }
    return Row(
      children: [
        Expanded(
          child: WntSearchableSelectField(
            label: label,
            value: selected?.value,
            hintText: hint,
            onTap: () async {
              final result = await showWntSearchPicker<MapEntry<int, String>>(
                context: context,
                title: 'Wybierz: $label',
                searchHint: searchHint,
                items: options,
                titleFor: (item) => item.value,
                searchTextFor: (item) => item.value,
                selected: selected,
              );
              if (result != null) onChanged(result.key);
            },
          ),
        ),
        if (selectedId != null) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Wyczyść: $label',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close),
          ),
        ],
      ],
    );
  }
}

Future<void> _openSanitizationEditor(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> data, {
  Map<String, dynamic>? item,
}) async {
  final clients = (data['sanitization_clients'] as List? ?? const [])
      .whereType<Map>()
      .map((row) => row.cast<String, dynamic>())
      .toList();
  final locations = (data['sanitization_locations'] as List? ?? const [])
      .whereType<Map>()
      .map((row) => row.cast<String, dynamic>())
      .toList();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _SanitizationSheet(item: item, clients: clients, locations: locations),
  );
  ref.invalidate(adminOperationsProvider);
}

class _SanitizationRouteSheet extends ConsumerStatefulWidget {
  const _SanitizationRouteSheet({required this.item, required this.data});

  final Map<String, dynamic> item;
  final Map<String, dynamic> data;

  @override
  ConsumerState<_SanitizationRouteSheet> createState() =>
      _SanitizationRouteSheetState();
}

class _SanitizationRouteSheetState
    extends ConsumerState<_SanitizationRouteSheet> {
  late final List<Map<String, dynamic>> routes =
      (widget.data['route_options'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
  late final List<Map<String, dynamic>> drivers =
      (widget.data['sanitization_drivers'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
  late String mode = routes.isEmpty ? 'new' : 'existing';
  late int routeId = routes.isEmpty ? 0 : _int(routes.first['id']);
  late int driverId = drivers.isEmpty ? 0 : _int(drivers.first['id']);
  late final TextEditingController position = TextEditingController(
    text: routes.isEmpty ? '1' : '${_int(routes.first['stops_count']) + 1}',
  );
  late final TextEditingController routeName = TextEditingController(
    text: 'Sanityzacja - ${widget.item['title']}',
  );
  DateTime date = DateTime.now().add(const Duration(days: 1));
  bool saving = false;

  @override
  void dispose() {
    position.dispose();
    routeName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if ((mode == 'existing' && routeId < 1) ||
        (mode == 'new' && (driverId < 1 || routeName.text.trim().isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz trasę i kierowcę.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .planSanitizationRoute(
            ref.read(authControllerProvider).session!.token,
            _int(widget.item['id']),
            <String, dynamic>{
              'route_mode': mode,
              'route_id': mode == 'existing' ? routeId : null,
              'route_position': mode == 'existing'
                  ? (_int(position.text) == 0 ? 1 : _int(position.text))
                  : null,
              'new_route_name': mode == 'new' ? routeName.text.trim() : null,
              'new_scheduled_date': mode == 'new' ? _isoDate(date) : null,
              'new_driver_id': mode == 'new' ? driverId : null,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${response['message'] ?? 'Dodano do trasy.'}'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .82,
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
                      'Zaplanuj zaległą sanityzację',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      widget.item['title']?.toString() ?? 'Klient',
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
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'existing',
                    label: Text('Istniejąca trasa'),
                  ),
                  ButtonSegment(value: 'new', label: Text('Nowa trasa')),
                ],
                selected: {mode},
                onSelectionChanged: (selection) =>
                    setState(() => mode = selection.first),
              ),
              const SizedBox(height: 14),
              if (mode == 'existing') ...[
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
                  onChanged: (value) {
                    if (value == null) return;
                    final route = routes.firstWhere(
                      (item) => _int(item['id']) == value,
                    );
                    setState(() {
                      routeId = value;
                      position.text = '${_int(route['stops_count']) + 1}';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: position,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pozycja klienta na trasie',
                  ),
                ),
              ] else ...[
                TextField(
                  controller: routeName,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa nowej trasy',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data nowej trasy'),
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
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route_outlined),
                label: const Text('Dodaj klienta i sanityzację do trasy'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SanitizationSheet extends ConsumerStatefulWidget {
  const _SanitizationSheet({
    required this.clients,
    required this.locations,
    this.item,
  });
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> locations;

  @override
  ConsumerState<_SanitizationSheet> createState() => _SanitizationSheetState();
}

class _SanitizationSheetState extends ConsumerState<_SanitizationSheet> {
  late int clientId = _int(widget.item?['client_id']);
  late int locationId = _int(widget.item?['client_location_id']);
  DateTime? lastSanitizedOn;
  final TextEditingController interval = TextEditingController(text: '180');
  final Set<String> selectedEquipmentKeys = {};
  bool saving = false;

  Map<String, dynamic>? get selectedClient {
    for (final client in widget.clients) {
      if (_int(client['id']) == clientId) return client;
    }
    return null;
  }

  Map<String, dynamic>? get selectedLocation {
    for (final location in widget.locations) {
      if (_int(location['id']) == locationId) return location;
    }
    return null;
  }

  List<Map<String, dynamic>> get availableLocations => widget.locations
      .where((location) => _int(location['client_id']) == clientId)
      .toList();

  List<Map<String, dynamic>> get equipmentUnits =>
      (selectedLocation?['equipment_units'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();

  @override
  void initState() {
    super.initState();
    if (clientId == 0 && widget.clients.isNotEmpty) {
      clientId = _int(widget.clients.first['id']);
    }
    if (locationId == 0 && availableLocations.isNotEmpty) {
      locationId = _int(availableLocations.first['id']);
    }
    _applyLocation(
      preserveSelected: (widget.item?['selected_equipment_keys'] as List?)
          ?.map((key) => '$key')
          .toSet(),
    );
  }

  @override
  void dispose() {
    interval.dispose();
    super.dispose();
  }

  void _applyLocation({Set<String>? preserveSelected}) {
    final location = selectedLocation;
    lastSanitizedOn = DateTime.tryParse(
      '${location?['last_sanitized_on'] ?? widget.item?['last_sanitized_on'] ?? ''}',
    );
    interval.text =
        '${_int(location?['sanitization_interval_days']) == 0
            ? _int(widget.item?['next_interval_days']) == 0
                  ? 180
                  : _int(widget.item?['next_interval_days'])
            : _int(location?['sanitization_interval_days'])}';
    final allowed = equipmentUnits.map((unit) => '${unit['key']}').toSet();
    selectedEquipmentKeys
      ..clear()
      ..addAll(
        preserveSelected == null
            ? allowed
            : preserveSelected.where(allowed.contains),
      );
  }

  Future<void> pickClient() async {
    final selected = await showWntSearchPicker<Map<String, dynamic>>(
      context: context,
      title: 'Wybierz klienta',
      searchHint: 'Wpisz nazwę klienta',
      items: widget.clients,
      selected: selectedClient,
      titleFor: (client) => '${client['name'] ?? ''}',
      subtitleFor: (client) =>
          '${_int(client['dispenser_count'])} elementów do sanityzacji',
      searchTextFor: (client) => '${client['name'] ?? ''}',
    );
    if (selected == null || !mounted) return;

    setState(() {
      clientId = _int(selected['id']);
      locationId = availableLocations.isEmpty
          ? 0
          : _int(availableLocations.first['id']);
      _applyLocation();
    });
  }

  Future<void> pickLocation() async {
    final selected = await showWntSearchPicker<Map<String, dynamic>>(
      context: context,
      title: 'Wybierz lokalizację',
      searchHint: 'Wpisz nazwę lub adres lokalizacji',
      items: availableLocations,
      selected: selectedLocation,
      titleFor: (location) => '${location['name'] ?? ''}',
      subtitleFor: (location) => '${location['address'] ?? ''}',
      searchTextFor: (location) =>
          '${location['name'] ?? ''} ${location['address'] ?? ''}',
    );
    if (selected == null || !mounted) return;
    setState(() {
      locationId = _int(selected['id']);
      _applyLocation();
    });
  }

  String get nextDueDate {
    if (lastSanitizedOn == null) return 'Uzupełnij datę ostatniej sanityzacji';
    final days = _int(interval.text);
    if (days < 1) return 'Podaj poprawny interwał';
    return _isoDate(lastSanitizedOn!.add(Duration(days: days)));
  }

  Future<void> save() async {
    if (clientId == 0 || locationId == 0 || selectedEquipmentKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wybierz klienta, lokalizację i konkretny sprzęt.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref.read(adminRepositoryProvider).saveSanitization(
        token,
        widget.item == null ? null : _int(widget.item!['id']),
        <String, dynamic>{
          'cycle_settings': true,
          'client_location_id': locationId,
          'last_sanitized_on': lastSanitizedOn == null
              ? null
              : _isoDate(lastSanitizedOn!),
          'sanitization_interval_days': _int(interval.text),
          'equipment_units': selectedEquipmentKeys.toList(),
        },
      );
      ref.invalidate(adminOperationsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${response['message'] ?? 'Zapisano.'}')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item == null
                          ? 'Ustaw cykl sanityzacji'
                          : 'Edytuj cykl sanityzacji',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Ostatnia sanityzacja, interwał i konkretny sprzęt.',
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
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              WntSearchableSelectField(
                label: 'Klient',
                value: selectedClient?['name']?.toString(),
                hintText: 'Wyszukaj klienta',
                onTap: widget.item != null || widget.clients.isEmpty
                    ? null
                    : pickClient,
              ),
              const SizedBox(height: 12),
              WntSearchableSelectField(
                label: 'Lokalizacja',
                value: selectedLocation?['name']?.toString(),
                hintText: 'Wybierz lokalizację',
                onTap: widget.item != null || availableLocations.isEmpty
                    ? null
                    : pickLocation,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data ostatniej sanityzacji'),
                subtitle: Text(
                  lastSanitizedOn == null
                      ? 'Brak daty'
                      : _isoDate(lastSanitizedOn!),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: lastSanitizedOn ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => lastSanitizedOn = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: interval,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Kolejna sanityzacja za ile dni',
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                color: WntColors.brandSoft,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sprzęt objęty cyklem · ${selectedEquipmentKeys.length} z ${equipmentUnits.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: equipmentUnits.isEmpty
                                ? null
                                : () => setState(
                                    () => selectedEquipmentKeys
                                      ..clear()
                                      ..addAll(
                                        equipmentUnits.map(
                                          (unit) => '${unit['key']}',
                                        ),
                                      ),
                                  ),
                            child: const Text('Zaznacz wszystkie'),
                          ),
                          TextButton(
                            onPressed: selectedEquipmentKeys.isEmpty
                                ? null
                                : () => setState(selectedEquipmentKeys.clear),
                            child: const Text('Wyczyść'),
                          ),
                        ],
                      ),
                      if (equipmentUnits.isEmpty)
                        const Text(
                          'Ta lokalizacja nie ma sprzętu wymagającego sanityzacji.',
                        )
                      else
                        for (final unit in equipmentUnits)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: selectedEquipmentKeys.contains(
                              '${unit['key']}',
                            ),
                            title: Text(
                              '${unit['label'] ?? unit['equipment_name'] ?? 'Urządzenie'}',
                            ),
                            onChanged: (selected) => setState(() {
                              final key = '${unit['key']}';
                              if (selected == true) {
                                selectedEquipmentKeys.add(key);
                              } else {
                                selectedEquipmentKeys.remove(key);
                              }
                            }),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: const Text('Wyliczony następny termin'),
                  subtitle: Text(nextDueDate),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Zapisz'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdminOrdersContent extends StatefulWidget {
  const _AdminOrdersContent({
    required this.data,
    required this.items,
    required this.onRefresh,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> items;
  final Future<void> Function() onRefresh;

  @override
  State<_AdminOrdersContent> createState() => _AdminOrdersContentState();
}

class _AdminOrdersContentState extends State<_AdminOrdersContent> {
  String status = 'open';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final orders = widget.items.where((order) {
      final rawStatus = '${order['status'] ?? ''}';
      final matchesStatus = switch (status) {
        'all' => true,
        'open' => !['completed', 'cancelled'].contains(rawStatus),
        _ => rawStatus == status,
      };
      if (!matchesStatus) return false;
      if (normalizedQuery.isEmpty) return true;
      return [
            order['title'],
            order['subtitle'],
            order['location'],
            order['document_number'],
          ]
          .where((value) => value != null)
          .join(' ')
          .toLowerCase()
          .contains(normalizedQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Szukaj klienta, zamówienia lub WZ',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 10),
          WntFilterTabs<String>(
            value: status,
            items: const [
              WntFilterTab(value: 'open', label: 'Otwarte'),
              WntFilterTab(value: 'new', label: 'Nowe'),
              WntFilterTab(value: 'processing', label: 'W realizacji'),
              WntFilterTab(value: 'planned', label: 'Zaplanowane'),
              WntFilterTab(value: 'completed', label: 'Wykonane'),
              WntFilterTab(value: 'cancelled', label: 'Anulowane'),
              WntFilterTab(value: 'all', label: 'Wszystkie'),
            ],
            onChanged: (value) => setState(() => status = value),
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Brak zamówień',
              message: 'Nie ma zamówień pasujących do wybranych filtrów.',
            ),
          for (final order in orders) ...[
            _OrderCard(
              order: order,
              onTap: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => _OrderSheet(
                    order: order,
                    routes: _maps(widget.data['route_options']),
                    documents: _maps(widget.data['completed_order_documents']),
                    clients: _maps(widget.data['order_clients']),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayStatus = '${order['display_status'] ?? order['status'] ?? ''}';
    final colors = _orderStatusColors(displayStatus);
    return Card(
      color: colors.$1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${order['title'] ?? 'Zamówienie'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _StatusBadge(status: displayStatus),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${order['subtitle'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if ('${order['location'] ?? ''}'.trim().isNotEmpty)
                Text(
                  '${order['location']}',
                  style: const TextStyle(color: WntColors.muted),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if ('${order['created_at'] ?? ''}'.isNotEmpty)
                    _OrderMeta(
                      Icons.schedule_outlined,
                      '${order['created_at']}',
                    ),
                  if ('${order['route_name'] ?? ''}'.isNotEmpty)
                    _OrderMeta(Icons.route_outlined, '${order['route_name']}'),
                  if ('${order['document_number'] ?? ''}'.isNotEmpty)
                    _OrderMeta(
                      Icons.description_outlined,
                      '${order['document_number']}',
                    ),
                  _OrderMeta(
                    Icons.payments_outlined,
                    'Wartość: ${_money(order['total_gross'])} zł',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: WntColors.muted),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: WntColors.muted)),
    ],
  );
}

List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
    ? raw.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList()
    : <Map<String, dynamic>>[];

(Color, Color) _orderStatusColors(String status) => switch (status) {
  'new' => (WntColors.errorSoft, WntColors.error),
  'overdue' => (WntColors.warningSoft, WntColors.warning),
  'completed' => (WntColors.successSoft, WntColors.success),
  'cancelled' => (WntColors.canvas, WntColors.muted),
  _ => (WntColors.brandSoft, WntColors.brand),
};

Future<void> _openOrderCreator(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> operations,
) async {
  final token = ref.read(authControllerProvider).session!.token;
  final options = await ref.read(adminRepositoryProvider).routeOptions(token);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OrderCreateSheet(options: options),
  );
}

class _OrderCreateSheet extends ConsumerStatefulWidget {
  const _OrderCreateSheet({required this.options});
  final Map<String, dynamic> options;
  @override
  ConsumerState<_OrderCreateSheet> createState() => _OrderCreateSheetState();
}

class _OrderCreateSheetState extends ConsumerState<_OrderCreateSheet> {
  int? clientId;
  int? locationId;
  final quantities = <int, int>{};
  final notes = TextEditingController();
  final productSearch = TextEditingController();
  String search = '';
  bool saving = false;
  bool showAllProducts = false;

  List<Map<String, dynamic>> get clients => _maps(widget.options['clients']);
  List<Map<String, dynamic>> get products => _maps(widget.options['products']);
  Map<String, dynamic>? get client => clients
      .cast<Map<String, dynamic>?>()
      .firstWhere((item) => _int(item?['id']) == clientId, orElse: () => null);
  List<Map<String, dynamic>> get locations => _maps(client?['locations']);

  @override
  void dispose() {
    notes.dispose();
    productSearch.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (clientId == null || quantities.values.every((value) => value < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wybierz klienta i dodaj przynajmniej jeden produkt.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref.read(adminRepositoryProvider).createOrder(
        token,
        {
          'client_id': clientId,
          if (locationId != null) 'client_location_id': locationId,
          'quantities': {
            for (final entry in quantities.entries) '${entry.key}': entry.value,
          },
          if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        },
      );
      ref.invalidate(adminOperationsProvider);
      ref.invalidate(adminSummaryProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${response['message'] ?? 'Zamówienie zostało utworzone.'}',
          ),
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
  Widget build(BuildContext context) {
    final selectedLocation = locations.firstWhere(
      (item) => _int(item['id']) == locationId,
      orElse: () => const {},
    );
    final locationProductIds =
        (selectedLocation['visible_product_ids'] as List?)
            ?.map(_int)
            .where((id) => id > 0)
            .toSet() ??
        <int>{};
    final clientProductIds =
        (client?['visible_product_ids'] as List?)
            ?.map(_int)
            .where((id) => id > 0)
            .toSet() ??
        <int>{};
    final assignedProductIds = locationProductIds.isNotEmpty
        ? locationProductIds
        : clientProductIds;
    final normalizedSearch = search.trim().toLowerCase();
    final assignedProducts = products
        .where((product) => assignedProductIds.contains(_int(product['id'])))
        .toList();
    final otherProducts = products
        .where((product) => !assignedProductIds.contains(_int(product['id'])))
        .toList();
    final productPool = showAllProducts
        ? [...assignedProducts, ...otherProducts]
        : assignedProducts;
    final shownProducts = productPool
        .where(
          (product) =>
              normalizedSearch.isEmpty ||
              '${product['name'] ?? ''}'.toLowerCase().contains(
                normalizedSearch,
              ),
        )
        .toList();
    return FractionallySizedBox(
      heightFactor: .94,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Nowe zamówienie',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: clientId,
                  decoration: const InputDecoration(labelText: 'Klient'),
                  items: clients
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
                  onChanged: (value) => setState(() {
                    clientId = value;
                    final defaultLocation = _maps(client?['locations'])
                        .firstWhere(
                          (item) => item['is_default'] == true,
                          orElse: () => const {},
                        );
                    locationId = _int(defaultLocation['id']) > 0
                        ? _int(defaultLocation['id'])
                        : (locations.isEmpty
                              ? null
                              : _int(locations.first['id']));
                    quantities.clear();
                    showAllProducts = false;
                    search = '';
                    productSearch.clear();
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: locationId,
                  decoration: const InputDecoration(labelText: 'Lokalizacja'),
                  items: locations
                      .map(
                        (item) => DropdownMenuItem(
                          value: _int(item['id']),
                          child: Text(
                            '${item['name']} - ${item['address'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: clientId == null
                      ? null
                      : (value) => setState(() {
                          locationId = value;
                          quantities.clear();
                          showAllProducts = false;
                          search = '';
                          productSearch.clear();
                        }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: productSearch,
                  decoration: const InputDecoration(
                    hintText: 'Szukaj produktu',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 8),
                for (final product in shownProducts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${product['name']}'),
                    subtitle: Text('${product['unit'] ?? 'szt.'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            final id = _int(product['id']);
                            quantities[id] = ((quantities[id] ?? 0) - 1).clamp(
                              0,
                              9999,
                            );
                          }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${quantities[_int(product['id'])] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            final id = _int(product['id']);
                            quantities[id] = (quantities[id] ?? 0) + 1;
                          }),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                if (otherProducts.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => showAllProducts = !showAllProducts),
                      icon: Icon(
                        showAllProducts ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: Text(
                        showAllProducts
                            ? 'Pokaż mniej produktów'
                            : 'Pokaż więcej produktów (${otherProducts.length})',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Uwagi'),
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
                  label: const Text('Utwórz zamówienie'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSheet extends ConsumerStatefulWidget {
  const _OrderSheet({
    required this.order,
    required this.routes,
    required this.documents,
    required this.clients,
  });
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> routes;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> clients;

  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  late int routeId = _int(widget.order['route_id']);
  bool saving = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anulować zamówienie?'),
        content: const Text(
          'Zamówienie pozostanie w historii jako anulowane. Planowany WZ i punkt dodany przez to zamówienie zostaną bezpiecznie odpięte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: WntColors.error),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Anuluj zamówienie'),
          ),
        ],
      ),
    );
    if (confirmed != true || saving) return;

    setState(() => saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      await ref
          .read(adminRepositoryProvider)
          .cancelOrder(token, _int(widget.order['id']));
      ref.invalidate(adminOperationsProvider);
      ref.invalidate(adminSummaryProvider);
      if (mounted) Navigator.pop(context, true);
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

  Future<void> _accept() async {
    setState(() => saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .updateOrderStatus(token, _int(widget.order['id']), 'processing');
      ref.invalidate(adminOperationsProvider);
      ref.invalidate(adminSummaryProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${response['message'] ?? 'Zamówienie przyjęto do realizacji.'}',
          ),
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

  List<Map<String, dynamic>> get _candidateDocuments {
    final clientId = _int(widget.order['client_id']);
    final orderLocation = _int(widget.order['client_location_id']);
    final client = widget.clients.firstWhere(
      (item) => _int(item['id']) == clientId,
      orElse: () => const {},
    );
    final defaultLocation = _int(client['default_location_id']);
    final effectiveOrderLocation = orderLocation > 0
        ? orderLocation
        : defaultLocation;
    return widget.documents.where((document) {
      if (_int(document['client_id']) != clientId) return false;
      final documentLocation = _int(document['client_location_id']);
      final effectiveDocumentLocation = documentLocation > 0
          ? documentLocation
          : defaultLocation;
      return effectiveDocumentLocation == effectiveOrderLocation;
    }).toList();
  }

  Future<void> _complete() async {
    int? selectedId;
    final documents = _candidateDocuments;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Zamknij zlecenie i przypisz WZ'),
          content: documents.isEmpty
              ? const Text(
                  'Brak zakończonego WZ dla tego klienta i tej lokalizacji od 1.09.2026.',
                )
              : DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'WZ realizujący zamówienie',
                  ),
                  items: documents
                      .map(
                        (document) => DropdownMenuItem<int>(
                          value: _int(document['id']),
                          child: Text(
                            '${document['number']} · ${document['date']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedId = value),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Wróć'),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Przypisz WZ i zamknij'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selectedId == null || saving) return;
    setState(() => saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .completeOrder(token, _int(widget.order['id']), selectedId!);
      ref.invalidate(adminOperationsProvider);
      ref.invalidate(adminSummaryProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message'] ?? 'Zamówienie zakończono.'}'),
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

  Future<void> _previewDocument() async {
    final documentId = _int(widget.order['document_id']);
    if (documentId < 1) return;
    setState(() => saving = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final pdf = await ref
          .read(adminRepositoryProvider)
          .documentPdf(token, documentId);
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}wz-$documentId.pdf',
      );
      await file.writeAsBytes(pdf.bytes, flush: true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfDocumentScreen(
            path: file.path,
            title: '${widget.order['document_number'] ?? 'WZ'}',
          ),
        ),
      );
      await PdfDocumentScreen.removeTemporary(file.path);
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
      ref.invalidate(adminOperationsProvider);
      ref.invalidate(adminSummaryProvider);
      if (mounted) Navigator.pop(context, true);
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
    final hasSelectedRoute =
        routeId == 0 ||
        widget.routes.any((route) => _int(route['id']) == routeId);
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WntColors.canvas,
                    borderRadius: BorderRadius.circular(12),
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
                        '${_money(widget.order['total_gross'] ?? widget.order['total'])} zł',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: routeId,
                  decoration: const InputDecoration(labelText: 'Trasa'),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Nieprzypisane'),
                    ),
                    if (!hasSelectedRoute)
                      DropdownMenuItem(
                        value: routeId,
                        child: Text(
                          'Obecnie przypisana trasa',
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  onChanged:
                      [
                        'completed',
                        'cancelled',
                      ].contains('${widget.order['status']}')
                      ? null
                      : (value) => setState(() => routeId = value ?? 0),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (![
                    'completed',
                    'cancelled',
                  ].contains('${widget.order['status']}'))
                    OutlinedButton.icon(
                      onPressed: saving ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Anuluj'),
                    ),
                  if ('${widget.order['status']}' == 'new')
                    FilledButton.tonalIcon(
                      onPressed: saving ? null : _accept,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Przyjmij'),
                    ),
                  if (![
                    'completed',
                    'cancelled',
                  ].contains('${widget.order['status']}'))
                    FilledButton.tonalIcon(
                      onPressed: saving ? null : _complete,
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: const Text('Zamknij z WZ'),
                    ),
                  if ('${widget.order['status']}' == 'completed' &&
                      _int(widget.order['document_id']) > 0)
                    FilledButton.tonalIcon(
                      onPressed: saving ? null : _previewDocument,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Podgląd WZ'),
                    ),
                  if (![
                    'completed',
                    'cancelled',
                  ].contains('${widget.order['status']}'))
                    FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.route_outlined),
                      label: const Text('Zapisz trasę'),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = _orderStatusColors(status);
    final label = switch (status) {
      'new' => 'Nowe',
      'processing' => 'W realizacji',
      'accepted' => 'Przyjęte',
      'planned' => 'Zaplanowane',
      'in_delivery' => 'W dostawie',
      'completed' => 'Wykonane',
      'overdue' => 'Po terminie',
      'in_progress' => 'Do dokończenia',
      'missed' => 'Nie zastano',
      'cancelled' => 'Anulowane',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colors.$2),
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
                  return _ProductStatusTabs(
                    active: _active,
                    onChanged: (value) => setState(() => _active = value),
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
String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _money(dynamic value) =>
    (double.tryParse('$value') ?? 0).toStringAsFixed(2).replaceFirst('.', ',');

class _ProductStatusTabs extends StatelessWidget {
  const _ProductStatusTabs({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => WntFilterTabs<bool>(
    value: active,
    items: const [
      WntFilterTab(value: true, label: 'Aktywne'),
      WntFilterTab(value: false, label: 'Wyłączone'),
    ],
    onChanged: onChanged,
  );
}
