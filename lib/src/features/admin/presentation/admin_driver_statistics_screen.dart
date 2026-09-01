import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';

class AdminDriverStatisticsScreen extends ConsumerStatefulWidget {
  const AdminDriverStatisticsScreen({super.key});

  @override
  ConsumerState<AdminDriverStatisticsScreen> createState() =>
      _AdminDriverStatisticsScreenState();
}

class _AdminDriverStatisticsScreenState
    extends ConsumerState<AdminDriverStatisticsScreen> {
  static const _ranges = <String, String>{
    'today': 'Dzisiaj',
    'yesterday': 'Wczoraj',
    'seven': '7 dni',
    'month': 'Miesiąc',
    'six_months': '6 mies.',
    'twelve_months': '12 mies.',
    'year': 'Rok',
  };

  int? _driverId;
  String _range = 'seven';
  DateTime _date = DateTime.now();
  late Future<Map<String, dynamic>> _result;

  @override
  void initState() {
    super.initState();
    _result = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final token = ref.read(authControllerProvider).session!.token;
    return ref
        .read(adminRepositoryProvider)
        .driverStatistics(
          token,
          driverId: _driverId,
          range: _range,
          date: DateFormat('yyyy-MM-dd').format(_date),
        );
  }

  void _reload() => setState(() => _result = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 42),
                const SizedBox(height: 12),
                Text('Nie udało się pobrać statystyk.\n${snapshot.error}'),
                const SizedBox(height: 16),
                FilledButton(onPressed: _reload, child: const Text('Ponów')),
              ],
            ),
          ),
        );
      }

      final data = snapshot.data!;
      final drivers = (data['drivers'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final stats = (data['stats'] as Map? ?? const {}).cast<String, dynamic>();
      final breakdown = (data['breakdown'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final monthly = (data['monthly'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .reversed
          .toList();
      final showMonthly = const {
        'six_months',
        'twelve_months',
        'year',
      }.contains(_range);

      return RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _result;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Statystyki kierowców',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text('Dane sprzedażowe i rzeczywisty przejazd z GPS Car.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _driverId,
              decoration: const InputDecoration(labelText: 'Kierowca'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Wszyscy kierowcy'),
                ),
                ...drivers.map(
                  (driver) => DropdownMenuItem<int?>(
                    value: (driver['id'] as num).toInt(),
                    child: Text(driver['name']?.toString() ?? 'Kierowca'),
                  ),
                ),
              ],
              onChanged: (value) {
                _driverId = value;
                _reload();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _periodLabel(data),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Wybierz datę',
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) {
                      _date = selected;
                      _reload();
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ranges.entries
                  .map(
                    (entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: _range == entry.key,
                      onSelected: (_) {
                        _range = entry.key;
                        _reload();
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      width: width,
                      icon: Icons.route_outlined,
                      label: 'Kilometry',
                      value: '${_number(stats['km'], 1)} km',
                    ),
                    _StatCard(
                      width: width,
                      icon: Icons.schedule_outlined,
                      label: 'Czas jazdy GPS',
                      value: _duration(stats['drive_minutes']),
                    ),
                    _StatCard(
                      width: width,
                      icon: Icons.description_outlined,
                      label: 'WZ zakończone',
                      value: '${stats['documents'] ?? 0}',
                    ),
                    _StatCard(
                      width: width,
                      icon: Icons.payments_outlined,
                      label: 'Wartość WZ',
                      value: '${_number(stats['value'], 2)} zł',
                    ),
                    _StatCard(
                      width: width,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Pobrana gotówka',
                      value: '${_number(stats['cash'], 2)} zł',
                    ),
                  ],
                );
              },
            ),
            if (_driverId == null && breakdown.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Porównanie kierowców',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'WZ, wartość, kilometry i czas dla wybranego zakresu.',
              ),
              const SizedBox(height: 10),
              _DriverComparison(rows: breakdown),
            ],
            if (showMonthly) ...[
              const SizedBox(height: 24),
              Text(
                'Ostatnie 12 miesięcy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: monthly.map((row) {
                    return Column(
                      children: [
                        ListTile(
                          title: Text(row['label']?.toString() ?? ''),
                          subtitle: Text(
                            '${_number(row['km'], 1)} km • ${_duration(row['drive_minutes'])}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_number(row['value'], 2)} zł',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text('${row['documents'] ?? 0} WZ'),
                            ],
                          ),
                        ),
                        if (row != monthly.last) const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  static String _number(dynamic value, int digits) => NumberFormat.currency(
    locale: 'pl_PL',
    symbol: '',
    decimalDigits: digits,
  ).format((value as num?)?.toDouble() ?? 0).trim();

  static String _duration(dynamic value) {
    final minutes = (value as num?)?.toInt() ?? 0;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0 ? '$hours h $rest min' : '$rest min';
  }

  static String _periodLabel(Map<String, dynamic> data) {
    final from = DateTime.tryParse(data['from']?.toString() ?? '');
    final to = DateTime.tryParse(data['to']?.toString() ?? '');
    if (from == null || to == null) return 'Wybrany okres';
    final formatter = DateFormat('dd.MM.yyyy');
    return from == to
        ? formatter.format(from)
        : '${formatter.format(from)} - ${formatter.format(to)}';
  }
}

class _DriverComparison extends StatelessWidget {
  const _DriverComparison({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final maxDocuments = _max('documents');
    final maxValue = _max('value');
    final maxKm = _max('km');
    final maxMinutes = _max('drive_minutes');
    final colors = <Color>[
      WntColors.brand,
      WntColors.error,
      Colors.green.shade600,
      Colors.orange.shade700,
      Colors.purple.shade600,
    ];

    return Column(
      children: rows.indexed.map((entry) {
        final index = entry.$1;
        final row = entry.$2;
        final color = colors[index % colors.length];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['name']?.toString() ?? 'Kierowca',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _ComparisonBar(
                  label: 'WZ',
                  value: '${row['documents'] ?? 0}',
                  progress: _ratio(row['documents'], maxDocuments),
                  color: color,
                ),
                _ComparisonBar(
                  label: 'Wartość',
                  value:
                      '${_AdminDriverStatisticsScreenState._number(row['value'], 2)} zł',
                  progress: _ratio(row['value'], maxValue),
                  color: color.withValues(alpha: .82),
                ),
                _ComparisonBar(
                  label: 'Kilometry',
                  value:
                      '${_AdminDriverStatisticsScreenState._number(row['km'], 1)} km',
                  progress: _ratio(row['km'], maxKm),
                  color: color.withValues(alpha: .66),
                ),
                _ComparisonBar(
                  label: 'Czas',
                  value: _AdminDriverStatisticsScreenState._duration(
                    row['drive_minutes'],
                  ),
                  progress: _ratio(row['drive_minutes'], maxMinutes),
                  color: color.withValues(alpha: .5),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  double _max(String key) => rows.fold<double>(
    0,
    (current, row) => ((row[key] as num?)?.toDouble() ?? 0) > current
        ? (row[key] as num).toDouble()
        : current,
  );

  static double _ratio(dynamic value, double maximum) => maximum <= 0
      ? 0
      : (((value as num?)?.toDouble() ?? 0) / maximum).clamp(0, 1);
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              color: color,
              backgroundColor: color.withValues(alpha: .12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: WntColors.brand),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
      ),
    ),
  );
}
