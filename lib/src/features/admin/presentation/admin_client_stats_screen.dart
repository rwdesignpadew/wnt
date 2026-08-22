import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_client_full_edit_screen.dart';

class AdminClientStatsScreen extends ConsumerStatefulWidget {
  const AdminClientStatsScreen({
    required this.clientId,
    this.locationId,
    super.key,
  });

  final int clientId;
  final int? locationId;

  @override
  ConsumerState<AdminClientStatsScreen> createState() =>
      _AdminClientStatsScreenState();
}

class _AdminClientStatsScreenState
    extends ConsumerState<AdminClientStatsScreen> {
  String _range = 'last_12_months';
  Map<String, dynamic>? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final data = await ref.read(adminRepositoryProvider).clientStats(
            token,
            widget.clientId,
            range: _range,
            locationId: widget.locationId,
          );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminClientFullEditScreen(id: widget.clientId),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final client = _map(_data?['client']);
    return Scaffold(
      appBar: AppBar(
        title: Text(client?['name']?.toString() ?? 'Statystyki klienta'),
        actions: [
          IconButton(
            tooltip: 'Edytuj klienta',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Nie udało się pobrać statystyk: $_error'),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Ponów')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _rangeSelector(),
                      const SizedBox(height: 14),
                      _summary(),
                      if (widget.locationId == null) ...[
                        const SizedBox(height: 14),
                        _recipients(),
                      ],
                      const SizedBox(height: 14),
                      _containers(),
                      const SizedBox(height: 14),
                      _rentals(),
                      const SizedBox(height: 14),
                      _monthly(),
                      const SizedBox(height: 14),
                      _documents(),
                    ],
                  ),
                ),
    );
  }

  Widget _rangeSelector() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'current_year', label: Text('Ten rok')),
            ButtonSegment(value: 'previous_year', label: Text('Poprzedni')),
            ButtonSegment(value: 'last_12_months', label: Text('12 mies.')),
            ButtonSegment(value: 'all', label: Text('Całość')),
          ],
          selected: {_range},
          onSelectionChanged: (value) {
            _range = value.first;
            _load();
          },
        ),
      );

  Widget _summary() {
    final totals = _map(_data?['totals']) ?? const {};
    return _CardSection(
      title: 'Podsumowanie',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Metric('Zamówiona woda', _number(totals['water_ordered'])),
          _Metric('Zwroty butli', _number(totals['bottles_returned'])),
          _Metric('Dokumenty WZ', _number(totals['documents'])),
          _Metric('Wartość', '${_money(totals['value'])} zł'),
          _Metric(
            'Pozostaje do zapłaty',
            '${_money(totals['remaining_due'])} zł',
            warning: _double(totals['remaining_due']) > 0,
          ),
        ],
      ),
    );
  }

  Widget _recipients() {
    final recipients = _list(_data?['recipients']);
    if (recipients.isEmpty) return const SizedBox.shrink();
    return _CardSection(
      title: 'Powiązani odbiorcy',
      child: Column(
        children: [
          for (final recipient in recipients)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(recipient['name']?.toString() ?? 'Odbiorca'),
              subtitle: Text([
                recipient['address'],
                recipient['nip'] == null ? null : 'NIP: ${recipient['nip']}',
              ].whereType<Object>().join('\n')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminClientStatsScreen(
                    clientId: widget.clientId,
                    locationId: _int(recipient['id']),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _containers() {
    final totals = _map(_data?['totals']) ?? const {};
    return _CardSection(
      title: 'Opakowania i sprzęt u klienta',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Metric('Butle 18,9 l', _number(totals['bottles_189_balance'])),
          _Metric('Butelki 0,3 l', _number(totals['small_bottles_balance'])),
          _Metric('Transportery', _number(totals['transporters_balance'])),
          _Metric('Dzierżawa', '${_number(totals['rental_items'])} szt.'),
        ],
      ),
    );
  }

  Widget _rentals() {
    final rentals = _list(_data?['rental_items']);
    final returns = _list(_data?['rental_returns']);
    if (rentals.isEmpty && returns.isEmpty) return const SizedBox.shrink();
    return _CardSection(
      title: 'Dzierżawa i zwroty sprzętu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in rentals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item['name']?.toString() ?? 'Sprzęt'),
              subtitle: Text(item['location']?.toString() ?? ''),
              trailing: Text('${_number(item['quantity'])} szt.'),
            ),
          for (final item in returns)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.keyboard_return),
              title: Text(item['name']?.toString() ?? 'Zwrot'),
              trailing: Text('${_number(item['quantity'])} szt.'),
            ),
        ],
      ),
    );
  }

  Widget _monthly() {
    final months = _list(_data?['months']);
    if (months.isEmpty) return const SizedBox.shrink();
    final maxValue = months.fold<double>(1, (max, month) {
      final value = _double(month['water_ordered']);
      return value > max ? value : max;
    });
    return _CardSection(
      title: 'Zamawianie wody miesięcznie',
      child: Column(
        children: [
          for (final month in months)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 58, child: Text('${month['label'] ?? ''}')),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_double(month['water_ordered']) / maxValue)
                          .clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      _number(month['water_ordered']),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _documents() {
    final documents = _list(_data?['documents']);
    if (documents.isEmpty) return const SizedBox.shrink();
    return _CardSection(
      title: 'Ostatnie dokumenty WZ',
      child: Column(
        children: [
          for (final document in documents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(document['number']?.toString() ?? 'WZ'),
              subtitle: Text([
                document['date'],
                document['location'],
              ].whereType<Object>().join(' · ')),
              trailing: Text('${_money(document['value'])} zł'),
            ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.warning = false});
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warning ? WntColors.errorSoft : WntColors.canvas,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      );
}

Map<String, dynamic>? _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : null;

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.map(_map).whereType<Map<String, dynamic>>().toList()
    : const [];

int _int(dynamic value) => int.tryParse('$value') ?? 0;
double _double(dynamic value) => double.tryParse('$value') ?? 0;
String _number(dynamic value) {
  final number = _double(value);
  return number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toStringAsFixed(1).replaceAll('.', ',');
}

String _money(dynamic value) =>
    _double(value).toStringAsFixed(2).replaceAll('.', ',');
