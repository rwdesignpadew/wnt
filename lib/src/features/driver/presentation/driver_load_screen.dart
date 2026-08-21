import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../application/driver_providers.dart';

class DriverLoadScreen extends ConsumerStatefulWidget {
  const DriverLoadScreen({super.key});

  @override
  ConsumerState<DriverLoadScreen> createState() => _DriverLoadScreenState();
}

class _DriverLoadScreenState extends ConsumerState<DriverLoadScreen> {
  String _selection = 'all';

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(driverRouteProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(driverRouteProvider),
          ),
          data: (data) {
            final totals = <String, int>{};
            final loadRoutes = _list(data['load_routes']);
            final selectedRoutes = _selection == 'all'
                ? loadRoutes
                : loadRoutes
                      .where((route) => '${route['id']}' == _selection)
                      .toList();
            if (loadRoutes.isNotEmpty) {
              for (final route in selectedRoutes) {
                for (final item in _list(route['items'])) {
                  final name = item['product_name']?.toString() ?? 'Produkt';
                  totals.update(
                    name,
                    (value) => value + _int(item['quantity']),
                    ifAbsent: () => _int(item['quantity']),
                  );
                }
              }
            } else {
              for (final document in _list(data['documents'])) {
                if (document['status'] == 'completed') continue;
                for (final item in _list(document['items'])) {
                  final name = item['product_name']?.toString() ?? 'Produkt';
                  totals.update(
                    name,
                    (value) => value + _int(item['quantity']),
                    ifAbsent: () => _int(item['quantity']),
                  );
                }
              }
            }
            final entries =
                totals.entries.where((entry) => entry.value > 0).toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(driverRouteProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Załadunek',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selection == 'all'
                        ? 'Suma produktów ze wszystkich tras bez powrotu do bazy.'
                        : 'Suma produktów dla wybranej trasy.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
                  ),
                  const SizedBox(height: 16),
                  if (loadRoutes.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selection,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Załadunek dla trasy',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('Wszystko — wszystkie trasy'),
                        ),
                        for (final route in loadRoutes)
                          DropdownMenuItem(
                            value: '${route['id']}',
                            child: Text(
                              '${route['scheduled_date']} — ${route['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selection = value ?? 'all'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (entries.isEmpty)
                    const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Brak produktów do załadunku',
                      message:
                          'Produkty pojawią się po dodaniu ich klientom na trasie.',
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < entries.length;
                            index++
                          ) ...[
                            ListTile(
                              title: Text(entries[index].key),
                              trailing: Text(
                                '${entries[index].value} szt.',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (index < entries.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
  }
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];
int _int(dynamic value) => int.tryParse('$value') ?? 0;
