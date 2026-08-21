import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../home/application/home_navigation_provider.dart';
import '../application/admin_providers.dart';
import 'admin_more_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _openRoutes(WidgetRef ref) =>
      ref.read(homeNavigationIndexProvider.notifier).state = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(adminSummaryProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminSummaryProvider),
        ),
        data: (data) {
          final alerts = _list(data['alerts']);
          final stats = _list(data['stats']);
          final routes = _list(data['routes']);
          final orders = _list(data['orders']);
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(adminSummaryProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Pulpit operacyjny',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sprawy wymagające reakcji i realizacja dzisiejszych tras.',
                ),
                const SizedBox(height: 20),
                Text(
                  'Realizacja dzisiaj',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 800
                        ? 3
                        : 2,
                    childAspectRatio: 2.1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${stats[index]['value']}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${stats[index]['label']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Wymaga uwagi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final alert in alerts)
                  _AlertCard(
                    alert: alert,
                    onTap: () {
                      final kind = '${alert['kind']}';
                      if (kind == 'routes') {
                        _openRoutes(ref);
                      } else {
                        _open(
                          context,
                          AdminOperationsScreen(
                            dataKey: kind,
                            title: kind == 'orders'
                                ? 'Zamówienia'
                                : 'Sanityzacje',
                          ),
                        );
                      }
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dzisiejsze trasy',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openRoutes(ref),
                      child: const Text('Wszystkie'),
                    ),
                  ],
                ),
                if (routes.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('Brak tras zaplanowanych na dzisiaj'),
                    ),
                  )
                else
                  for (final route in routes) _RouteProgress(route: route),
                const SizedBox(height: 16),
                Text(
                  'Najnowsze zamówienia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  const Card(
                    child: ListTile(title: Text('Brak nowych zamówień')),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var index = 0; index < orders.length; index++) ...[
                          ListTile(
                            leading: const Icon(Icons.shopping_bag_outlined),
                            title: Text('${orders[index]['number']}'),
                            subtitle: Text('${orders[index]['client']}'),
                            onTap: () => _open(
                              context,
                              const AdminOperationsScreen(
                                dataKey: 'orders',
                                title: 'Zamówienia',
                              ),
                            ),
                          ),
                          if (index < orders.length - 1)
                            const Divider(height: 1),
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});
  final Map<String, dynamic> alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse('${alert['value']}') ?? 0;
    return Card(
      color: count > 0 ? WntColors.errorSoft : WntColors.successSoft,
      child: ListTile(
        leading: Icon(
          count > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          color: count > 0 ? WntColors.error : WntColors.success,
        ),
        title: Text('${alert['label']}'),
        trailing: Text(
          '$count',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: count > 0 ? WntColors.error : WntColors.success,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RouteProgress extends StatelessWidget {
  const _RouteProgress({required this.route});
  final Map<String, dynamic> route;

  @override
  Widget build(BuildContext context) {
    final completed = int.tryParse('${route['completed']}') ?? 0;
    final total = int.tryParse('${route['total']}') ?? 0;
    final progress = total == 0 ? 0.0 : completed / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${route['name']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${route['driver']} · $completed z $total punktów'),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];
