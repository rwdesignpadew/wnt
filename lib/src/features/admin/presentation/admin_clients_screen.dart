import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_client_full_edit_screen.dart';
import 'admin_route_edit_screen.dart';

class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});
  @override
  ConsumerState<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  String _query = '';
  bool _active = true;

  Future<void> _openClient(int id, {int tab = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminClientFullEditScreen(id: id, initialTab: tab),
      ),
    );
    ref.invalidate(adminClientsProvider);
  }

  Future<void> _addToRoute(Map<String, dynamic> client) async {
    final routes = await ref.read(adminRoutesProvider.future);
    if (!mounted) return;
    final active = routes
        .where((route) => route['is_archived'] != true)
        .toList();
    final route = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dodaj klienta do trasy'),
        children: active.isEmpty
            ? [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, <String, dynamic>{
                    'create_new': true,
                  }),
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_road_outlined),
                    title: Text('Utwórz nową trasę'),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Brak bieżących tras.'),
                ),
              ]
            : [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, <String, dynamic>{
                    'create_new': true,
                  }),
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_road_outlined),
                    title: Text('Utwórz nową trasę'),
                  ),
                ),
                const Divider(),
                for (final item in active)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, item),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.route_outlined),
                      title: Text(item['title']?.toString() ?? 'Trasa'),
                      subtitle: Text(item['subtitle']?.toString() ?? ''),
                    ),
                  ),
              ],
      ),
    );
    if (route == null || !mounted) return;
    if (route['create_new'] == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AdminRouteEditScreen(initialClientId: _int(client['id'])),
        ),
      );
      ref.invalidate(adminRoutesProvider);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminRouteEditScreen(
          id: _int(route['id']),
          initialClientId: _int(client['id']),
        ),
      ),
    );
    ref.invalidate(adminRoutesProvider);
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(adminClientsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminClientsProvider),
        ),
        data: (all) {
          final query = _query.trim().toLowerCase();
          final byStatus = all
              .where(
                (item) => (item['status']?.toString() == 'aktywny') == _active,
              )
              .toList();
          final items = query.isEmpty
              ? byStatus
              : byStatus
                    .where(
                      (item) =>
                          '${item['title']} ${item['subtitle']} ${item['meta']}'
                              .toLowerCase()
                              .contains(query),
                    )
                    .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(adminClientsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 3,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Klienci',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminClientFullEditScreen(),
                            ),
                          );
                          ref.invalidate(adminClientsProvider);
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Nowy klient'),
                      ),
                    ],
                  );
                }
                if (index == 1) {
                  final activeCount = all
                      .where((item) => item['status']?.toString() == 'aktywny')
                      .length;
                  return SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text('Aktywni ($activeCount)'),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Nieaktywni (${all.length - activeCount})'),
                      ),
                    ],
                    selected: {_active},
                    onSelectionChanged: (value) =>
                        setState(() => _active = value.first),
                  );
                }
                if (index == 2) {
                  return TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Nazwa, adres, telefon lub email',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  );
                }
                final client = items[index - 3];
                final id = _int(client['id']);
                final sanitationOverdue =
                    client['has_overdue_sanitization'] == true;
                return Card(
                  color: sanitationOverdue ? WntColors.errorSoft : null,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.person_outline,
                          color: WntColors.brand,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _clientListTitle(client['title']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (sanitationOverdue)
                              const Chip(
                                avatar: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                ),
                                label: Text('Sanityzacja po terminie'),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${client['subtitle'] ?? ''}\n${client['meta'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openClient(id),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _openClient(id),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edytuj'),
                            ),
                            TextButton.icon(
                              onPressed: () => _openClient(id, tab: 2),
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: const Text('Produkty'),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Dodaj do trasy',
                              onPressed: () => _addToRoute(client),
                              icon: const Icon(Icons.add_road_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
}

String _clientListTitle(dynamic rawName) {
  final name = rawName?.toString().trim() ?? '';
  final match = RegExp(
    r'^1[.)]\s*(.+?)(?=\s+2[.)]\s|$)',
    caseSensitive: false,
  ).firstMatch(name);
  return match?.group(1)?.trim().isNotEmpty == true
      ? match!.group(1)!.trim()
      : (name.isEmpty ? 'Klient' : name);
}

class AdminClientEditScreen extends ConsumerStatefulWidget {
  const AdminClientEditScreen({required this.id, super.key});
  final int id;
  @override
  ConsumerState<AdminClientEditScreen> createState() =>
      _AdminClientEditScreenState();
}

class _AdminClientEditScreenState extends ConsumerState<AdminClientEditScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  Map<String, dynamic>? _client;
  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  bool _recipient = false;
  bool _jst = false;
  String _payment = 'transfer';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: _client?[key]?.toString() ?? ''),
  );

  Future<void> _load() async {
    try {
      final session = ref.read(authControllerProvider).session!;
      final response = await ref
          .read(adminRepositoryProvider)
          .client(session.token, widget.id);
      _client = _map(response['client']) ?? {};
      _active = _client?['is_active'] == true;
      _recipient = _client?['invoice_recipient_enabled'] == true;
      _jst = _client?['invoice_jst_enabled'] == true;
      _payment = _client?['payment_method']?.toString() == 'cash'
          ? 'cash'
          : 'transfer';
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final session = ref.read(authControllerProvider).session!;
      await ref.read(adminRepositoryProvider).updateClient(
        session.token,
        widget.id,
        {
          for (final key in [
            'name',
            'contact_person',
            'email',
            'phone',
            'delivery_address',
            'invoice_name',
            'invoice_nip',
            'invoice_address',
            'invoice_recipient_name',
            'invoice_recipient_nip',
            'invoice_recipient_address',
            'invoice_recipient_email',
          ])
            key: _c(key).text.trim(),
          'invoice_recipient_enabled': _recipient,
          'invoice_recipient_jst': _recipient && _jst,
          'invoice_jst_enabled': _jst,
          'payment_method': _payment,
          'payment_term_days': int.tryParse(_c('payment_term_days').text) ?? 0,
          'is_active': _active,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Klient został zapisany.'),
          backgroundColor: WntColors.success,
        ),
      );
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
    appBar: AppBar(title: const Text('Edytuj klienta')),
    bottomNavigationBar: SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: WntColors.line)),
        ),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Zapisywanie...' : 'Zapisz zmiany'),
        ),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(context, 'Dane klienta', [
                  _field('name', 'Nazwa klienta', required: true),
                  _row(
                    _field('contact_person', 'Osoba kontaktowa'),
                    _field('phone', 'Telefon', keyboard: TextInputType.phone),
                  ),
                  _field(
                    'email',
                    'Email',
                    keyboard: TextInputType.emailAddress,
                  ),
                  _field('delivery_address', 'Adres dostawy', lines: 2),
                ]),
                const SizedBox(height: 12),
                _section(context, 'Dane do faktury', [
                  _row(
                    _field('invoice_name', 'Nazwa do faktury'),
                    _field('invoice_nip', 'NIP'),
                  ),
                  _field('invoice_address', 'Adres do faktury', lines: 2),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Faktura dla JST'),
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
                    _row(
                      _field('invoice_recipient_nip', 'NIP odbiorcy'),
                      _field('invoice_recipient_email', 'Email odbiorcy'),
                    ),
                    _field(
                      'invoice_recipient_address',
                      'Adres odbiorcy',
                      lines: 2,
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                _section(context, 'Płatność', [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('Gotówka')),
                      ButtonSegment(value: 'transfer', label: Text('Przelew')),
                    ],
                    selected: {_payment},
                    onSelectionChanged: (value) =>
                        setState(() => _payment = value.first),
                  ),
                  _field(
                    'payment_term_days',
                    'Termin płatności (dni)',
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
            ),
          ),
  );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _c(key),
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
  Widget _row(Widget left, Widget right) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 10),
      Expanded(child: right),
    ],
  );
  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
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
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : null;
int _int(dynamic value) => int.tryParse('$value') ?? 0;
