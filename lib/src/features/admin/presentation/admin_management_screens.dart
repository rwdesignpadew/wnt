import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';

class AdminBalancesScreen extends ConsumerWidget {
  const AdminBalancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Salda klientów')),
    body: ref
        .watch(adminBalancesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _Error('$e', () => ref.invalidate(adminBalancesProvider)),
          data: (data) {
            final items = _maps(data['items']);
            return RefreshIndicator(
              onRefresh: () => ref.refresh(adminBalancesProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Card(
                    child: ListTile(
                      title: Text('${item['name'] ?? ''}'),
                      subtitle: Text(
                        'Zaległość: ${item['total_debt'] ?? 0} zł  •  Nadpłata: ${item['overpayment'] ?? 0} zł',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editBalance(context, ref, item),
                    ),
                  );
                },
              ),
            );
          },
        ),
  );

  Future<void> _editBalance(
    BuildContext context,
    WidgetRef ref,
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
  }
}

class AdminRentalsScreen extends ConsumerWidget {
  const AdminRentalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Dzierżawy')),
    body: ref
        .watch(adminRentalsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _Error('$e', () => ref.invalidate(adminRentalsProvider)),
          data: (data) {
            final pending = _maps(data['pending']);
            final active = _maps(data['active']);
            return RefreshIndicator(
              onRefresh: () => ref.refresh(adminRentalsProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (pending.isNotEmpty) const _Title('W realizacji'),
                  ...pending.map((e) => _RentalTile(e, pending: true)),
                  const _Title('Aktywne dzierżawy'),
                  ...active.map((e) => _RentalTile(e)),
                ],
              ),
            );
          },
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

class _RentalTile extends StatelessWidget {
  const _RentalTile(this.item, {this.pending = false});
  final Map<String, dynamic> item;
  final bool pending;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(pending ? Icons.schedule : Icons.water_drop_outlined),
      title: Text('${item['client_name']} - ${item['location_name']}'),
      subtitle: Text(
        '${item['product_name']} • ${item['quantity']} szt.${pending ? '\n${item['date'] ?? ''} - ${item['route_name'] ?? 'bez trasy'}' : ''}',
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
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
