import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/client_providers.dart';

class ClientServiceScreen extends ConsumerStatefulWidget {
  const ClientServiceScreen({super.key});

  @override
  ConsumerState<ClientServiceScreen> createState() =>
      _ClientServiceScreenState();
}

class _ClientServiceScreenState extends ConsumerState<ClientServiceScreen> {
  final description = TextEditingController();
  int rentalId = 0;
  bool sending = false;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (rentalId == 0 || description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz sprzęt i opisz problem.')),
      );
      return;
    }
    setState(() => sending = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(clientRepositoryProvider)
          .requestService(token, rentalId, description.text.trim());
      description.clear();
      ref.invalidate(clientHomeProvider);
      if (mounted) {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${response['message'] ?? 'Zgłoszenie wysłane.'}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    }
  }

  Future<void> openServiceForm(List<Map<String, dynamic>> rentals) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Zamów serwis',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Anuluj',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: rentalId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sprzęt'),
                  items: rentals
                      .map(
                        (rental) => DropdownMenuItem<int>(
                          value: int.tryParse('${rental['id']}') ?? 0,
                          child: Text(
                            '${rental['name']} - ${rental['location'] ?? 'Główna lokalizacja'} (${rental['quantity']} szt.)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => rentalId = value ?? 0,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: description,
                  minLines: 4,
                  maxLines: 8,
                  autofocus: true,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Opis problemu',
                    alignLabelWithHint: true,
                    hintText: 'Opisz usterkę i objawy...',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          if (rentalId == 0 ||
                              description.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Wybierz sprzęt i opisz problem.',
                                ),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => sending = true);
                          await send();
                          if (sheetContext.mounted &&
                              !sending &&
                              description.text.isEmpty) {
                            Navigator.of(sheetContext).pop();
                          } else if (sheetContext.mounted) {
                            setSheetState(() {});
                          }
                        },
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Wyślij zgłoszenie'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(clientHomeProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          final rentals = (data['service_rentals'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => row.cast<String, dynamic>())
              .toList();
          final requests = (data['service_requests'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => row.cast<String, dynamic>())
              .toList();
          final openCount = requests
              .where(
                (item) =>
                    !['completed', 'cancelled'].contains('${item['status']}'),
              )
              .length;
          final completedCount = requests
              .where((item) => item['status'] == 'completed')
              .length;
          if (rentals.isEmpty) {
            return const Center(child: Text('Brak aktywnej dzierżawy.'));
          }
          if (rentalId == 0) {
            rentalId = int.tryParse('${rentals.first['id']}') ?? 0;
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(clientHomeProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: () => openServiceForm(rentals),
                  icon: const Icon(Icons.build_outlined),
                  label: const Text('Zamów serwis'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Twoje zgłoszenia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Otwarte',
                        value: openCount,
                        color: WntColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Zakończone',
                        value: completedCount,
                        color: WntColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Nie masz jeszcze zgłoszeń serwisowych.'),
                    ),
                  )
                else
                  for (final request in requests) ...[
                    _ServiceRequestCard(request: request),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ServiceRequestCard extends StatelessWidget {
  const _ServiceRequestCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final status = '${request['status']}';
    final color = switch (status) {
      'completed' => WntColors.success,
      'cancelled' => WntColors.error,
      'planned' => WntColors.brand,
      _ => WntColors.warning,
    };
    final details = <String>[
      if ('${request['scheduled_date'] ?? ''}'.isNotEmpty)
        'Termin: ${request['scheduled_date']}',
      if ('${request['driver'] ?? ''}'.isNotEmpty)
        'Kierowca: ${request['driver']}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${request['equipment'] ?? 'Sprzęt'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${request['status_label'] ?? status}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${request['location'] ?? ''} · ${request['created_at'] ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text('${request['description'] ?? ''}'),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                details.join('\n'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WntColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if ('${request['admin_notes'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WntColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Informacja z serwisu: ${request['admin_notes']}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
