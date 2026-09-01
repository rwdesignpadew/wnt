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
            final routes = _list(data['routes']);
            final selectedRoute = data['selected_route'] is Map
                ? (data['selected_route'] as Map).cast<String, dynamic>()
                : null;
            final selectedRouteId = _intOrNull(selectedRoute?['id']);
            final documents = _list(data['documents']);

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
                    'Punkty i produkty do załadowania dla jednej wybranej trasy.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
                  ),
                  const SizedBox(height: 16),
                  if (routes.isEmpty)
                    const EmptyState(
                      icon: Icons.route_outlined,
                      title: 'Brak tras do załadunku',
                      message: 'Załadunek pojawi się po przypisaniu trasy.',
                    )
                  else ...[
                    DropdownButtonFormField<int>(
                      initialValue: selectedRouteId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Trasa'),
                      items: [
                        for (final route in routes)
                          DropdownMenuItem(
                            value: _intOrNull(route['id']),
                            child: Text(
                              '${route['scheduled_date'] ?? ''} - ${route['name'] ?? 'Trasa'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null || value == selectedRouteId) return;
                        ref.read(selectedDriverRouteIdProvider.notifier).state =
                            value;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (documents.isEmpty)
                      const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Brak punktów na trasie',
                        message: 'Wybrana trasa nie ma jeszcze klientów.',
                      )
                    else
                      for (var index = 0; index < documents.length; index++)
                        _LoadStopCard(index: index, document: documents[index]),
                  ],
                ],
              ),
            );
          },
        );
  }
}

class _LoadStopCard extends StatelessWidget {
  const _LoadStopCard({required this.index, required this.document});

  final int index;
  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final client = document['client'] is Map
        ? (document['client'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final location = document['location'] is Map
        ? (document['location'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final items = _list(
      document['items'],
    ).where((item) => _int(item['quantity']) > 0).toList();
    final address = (location['address'] ?? document['delivery_address'] ?? '')
        .toString();
    final locationName = location['name']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 18, child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client['name']?.toString() ?? 'Klient',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (locationName != null && locationName.isNotEmpty)
                        Text(locationName),
                      if (address.isNotEmpty)
                        Text(
                          address,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: WntColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (items.isEmpty)
              Text(
                'Brak zapisanych produktów - przygotuj miejsce na zamówienie.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: WntColors.muted),
              )
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['product_name']?.toString() ?? 'Produkt',
                        ),
                      ),
                      Text(
                        '${_int(item['quantity'])} szt.',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

int _int(dynamic value) => int.tryParse('$value') ?? 0;
int? _intOrNull(dynamic value) => int.tryParse('$value');
