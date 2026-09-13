import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/wnt_filter_tabs.dart';
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
  String section = 'service';
  int rentalId = 0;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<bool> sendService() async {
    if (rentalId == 0 || description.text.trim().isEmpty) {
      _message('Wybierz sprzęt i opisz problem.', error: true);
      return false;
    }
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(clientRepositoryProvider)
          .requestService(token, rentalId, description.text.trim());
      description.clear();
      ref.invalidate(clientHomeProvider);
      _message('${response['message'] ?? 'Zgłoszenie wysłane.'}');
      return true;
    } catch (error) {
      _message('$error', error: true);
      return false;
    }
  }

  Future<bool> sendSanitization(int locationId, int count) async {
    if (locationId < 1 || count < 1) {
      _message('Wybierz lokalizację i liczbę dystrybutorów.', error: true);
      return false;
    }
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(clientRepositoryProvider)
          .requestSanitization(
            token: token,
            locationId: locationId,
            dispenserCount: count,
          );
      ref.invalidate(clientHomeProvider);
      _message(
        '${response['message'] ?? 'Sanityzacja na żądanie została zamówiona.'}',
      );
      return true;
    } catch (error) {
      _message('$error', error: true);
      return false;
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? WntColors.error : WntColors.success,
      ),
    );
  }

  Future<void> openServiceForm(List<Map<String, dynamic>> rentals) async {
    var sheetSaving = false;
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
                          value: _int(rental['id']),
                          child: Text(
                            '${rental['name']} — ${rental['location'] ?? 'Główna lokalizacja'} (${rental['quantity']} szt.)',
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
                  onPressed: sheetSaving
                      ? null
                      : () async {
                          setSheetState(() => sheetSaving = true);
                          final saved = await sendService();
                          if (saved && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          } else if (sheetContext.mounted) {
                            setSheetState(() => sheetSaving = false);
                          }
                        },
                  icon: sheetSaving
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

  Future<void> openSanitizationForm(
    List<Map<String, dynamic>> locations,
  ) async {
    var locationId = _int(locations.first['id']);
    var maximum = _int(locations.first['max_dispenser_count']);
    var count = 1;
    var sheetSaving = false;
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
                        'Sanityzacja na żądanie',
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
                const SizedBox(height: 6),
                Text(
                  'Wybierz lokalizację i liczbę dystrybutorów.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: locationId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lokalizacja'),
                  items: locations
                      .map(
                        (location) => DropdownMenuItem<int>(
                          value: _int(location['id']),
                          child: Text(
                            '${location['name']} — maks. ${location['max_dispenser_count']} szt.',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() {
                    locationId = value ?? 0;
                    final selected = locations.firstWhere(
                      (location) => _int(location['id']) == locationId,
                    );
                    maximum = _int(selected['max_dispenser_count']);
                    count = count.clamp(1, maximum);
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  'Liczba dystrybutorów',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: WntColors.inputLine),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Zmniejsz',
                        onPressed: count > 1
                            ? () => setSheetState(() => count--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Expanded(
                        child: Text(
                          '$count z $maximum',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Zwiększ',
                        onPressed: count < maximum
                            ? () => setSheetState(() => count++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: sheetSaving
                      ? null
                      : () async {
                          setSheetState(() => sheetSaving = true);
                          final saved = await sendSanitization(
                            locationId,
                            count,
                          );
                          if (saved && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          } else if (sheetContext.mounted) {
                            setSheetState(() => sheetSaving = false);
                          }
                        },
                  icon: sheetSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.water_drop_outlined),
                  label: const Text('Zamów sanityzację'),
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
          final rentals = _mapList(data['service_rentals']);
          final serviceRequests = _mapList(data['service_requests']);
          final sanitizationLocations = _mapList(
            data['sanitization_locations'],
          );
          final sanitizationRequests = _mapList(data['sanitization_requests']);
          if (rentals.isEmpty && sanitizationLocations.isEmpty) {
            return const Center(child: Text('Brak aktywnej dzierżawy.'));
          }
          if (rentalId == 0 && rentals.isNotEmpty) {
            rentalId = _int(rentals.first['id']);
          }
          final openCount = serviceRequests
              .where(
                (item) =>
                    !['completed', 'cancelled'].contains('${item['status']}'),
              )
              .length;
          final completedCount = serviceRequests
              .where((item) => item['status'] == 'completed')
              .length;

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(clientHomeProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WntFilterTabs<String>(
                  value: section,
                  items: const [
                    WntFilterTab(value: 'service', label: 'Serwis'),
                    WntFilterTab(
                      value: 'sanitizations',
                      label: 'Sanityzacje na żądanie',
                    ),
                  ],
                  onChanged: (value) => setState(() => section = value),
                ),
                const SizedBox(height: 18),
                if (section == 'service') ...[
                  if (rentals.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () => openServiceForm(rentals),
                      icon: const Icon(Icons.build_outlined),
                      label: const Text('Zamów serwis'),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Twoje zgłoszenia serwisowe',
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
                  if (serviceRequests.isEmpty)
                    const _EmptyCard(
                      text: 'Nie masz jeszcze zgłoszeń serwisowych.',
                    )
                  else
                    for (final request in serviceRequests) ...[
                      _ServiceRequestCard(request: request),
                      const SizedBox(height: 10),
                    ],
                ] else ...[
                  if (sanitizationLocations.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () =>
                          openSanitizationForm(sanitizationLocations),
                      icon: const Icon(Icons.water_drop_outlined),
                      label: const Text('Zamów sanityzację'),
                    )
                  else
                    const _EmptyCard(
                      text:
                          'Brak dystrybutorów, dla których można zamówić sanityzację.',
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Twoje sanityzacje na żądanie',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (sanitizationRequests.isEmpty)
                    const _EmptyCard(
                      text:
                          'Nie masz jeszcze sanityzacji zamówionych na żądanie.',
                    )
                  else
                    for (final request in sanitizationRequests) ...[
                      _SanitizationRequestCard(request: request),
                      const SizedBox(height: 10),
                    ],
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Text(text)),
  );
}

class _ServiceRequestCard extends StatelessWidget {
  const _ServiceRequestCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final status = '${request['status']}';
    final details = <String>[
      if ('${request['scheduled_date'] ?? ''}'.isNotEmpty)
        'Termin: ${request['scheduled_date']}',
      if ('${request['driver'] ?? ''}'.isNotEmpty)
        'Kierowca: ${request['driver']}',
    ];
    return _RequestCard(
      title: '${request['equipment'] ?? 'Sprzęt'}',
      status: status,
      statusLabel: '${request['status_label'] ?? status}',
      subtitle: '${request['location'] ?? ''} · ${request['created_at'] ?? ''}',
      body: '${request['description'] ?? ''}',
      details: details,
      adminNotes: '${request['admin_notes'] ?? ''}',
    );
  }
}

class _SanitizationRequestCard extends StatelessWidget {
  const _SanitizationRequestCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final status = '${request['status']}';
    final details = <String>[
      if ('${request['route'] ?? ''}'.isNotEmpty) 'Trasa: ${request['route']}',
      if ('${request['scheduled_date'] ?? ''}'.isNotEmpty)
        'Termin: ${request['scheduled_date']}',
      if ('${request['driver'] ?? ''}'.isNotEmpty)
        'Kierowca: ${request['driver']}',
    ];
    return _RequestCard(
      title: '${request['location'] ?? 'Główna lokalizacja'}',
      status: status,
      statusLabel: '${request['status_label'] ?? status}',
      subtitle:
          '${request['dispenser_count'] ?? 0} szt. · '
          '${request['created_at'] ?? ''}',
      details: details,
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.subtitle,
    this.body,
    this.details = const [],
    this.adminNotes,
  });

  final String title;
  final String status;
  final String statusLabel;
  final String subtitle;
  final String? body;
  final List<String> details;
  final String? adminNotes;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => WntColors.success,
      'cancelled' || 'missed' || 'overdue' => WntColors.error,
      'planned' => WntColors.brand,
      _ => WntColors.warning,
    };
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
                    title,
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
                    statusLabel,
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
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (body?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(body!),
            ],
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
            if (adminNotes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WntColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Informacja z serwisu: $adminNotes'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : const [];

int _int(dynamic value) => int.tryParse('$value') ?? 0;
