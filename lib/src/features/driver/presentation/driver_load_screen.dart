import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../application/driver_providers.dart';

class DriverLoadScreen extends ConsumerWidget {
  const DriverLoadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    'Suma produktów zaplanowanych dla nieobsłużonych punktów.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
                  ),
                  const SizedBox(height: 16),
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
