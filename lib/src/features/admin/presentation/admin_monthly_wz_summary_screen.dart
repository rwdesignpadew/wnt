import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/presentation/html_document_screen.dart';
import '../../documents/presentation/pdf_document_screen.dart';
import '../application/admin_providers.dart';
import 'admin_bottom_navigation.dart';

class AdminMonthlyWzSummaryScreen extends ConsumerStatefulWidget {
  const AdminMonthlyWzSummaryScreen({super.key});

  @override
  ConsumerState<AdminMonthlyWzSummaryScreen> createState() =>
      _AdminMonthlyWzSummaryScreenState();
}

class _AdminMonthlyWzSummaryScreenState
    extends ConsumerState<AdminMonthlyWzSummaryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<Map<String, dynamic>> _result;
  int? _busyDocumentId;
  final Set<int> _savingPreferences = {};

  @override
  void initState() {
    super.initState();
    _result = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final token = ref.read(authControllerProvider).session!.token;
    return ref
        .read(adminRepositoryProvider)
        .monthlyWzSummary(token, DateFormat('yyyy-MM').format(_month));
  }

  void _reload() => setState(() => _result = _load());

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      helpText: 'Wybierz miesiąc podsumowania',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = DateTime(picked.year, picked.month);
      _result = _load();
    });
  }

  Future<void> _openWz(Map<String, dynamic> document) async {
    final id = _int(document['id']);
    if (id < 1) return;
    setState(() => _busyDocumentId = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final download = await ref
          .read(adminRepositoryProvider)
          .documentPdf(token, id);
      if (!mounted) return;
      final title = document['number']?.toString() ?? 'WZ';
      if (download.contentType.contains('text/html')) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HtmlDocumentScreen(
              html: utf8.decode(download.bytes),
              title: title,
            ),
          ),
        );
        return;
      }
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}miesieczne-wz-$id.pdf',
      );
      await file.writeAsBytes(download.bytes, flush: true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfDocumentScreen(path: file.path, title: title),
        ),
      );
      await PdfDocumentScreen.removeTemporary(file.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busyDocumentId = null);
    }
  }

  Future<void> _setPreference(Map<String, dynamic> client, bool enabled) async {
    final id = _int(client['client_id']);
    if (id < 1 || _savingPreferences.contains(id)) return;
    setState(() {
      _savingPreferences.add(id);
      client['email_monthly_wz_with_invoice'] = enabled;
    });
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .updateMonthlyWzEmailPreference(token, id, enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']?.toString() ?? 'Zapisano.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => client['email_monthly_wz_with_invoice'] = !enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPreferences.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('WZ do faktur miesięcznych')),
    bottomNavigationBar: adminBottomNavigation(context, ref),
    body: FutureBuilder<Map<String, dynamic>>(
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
                  Text('Nie udało się pobrać podsumowania.\n${snapshot.error}'),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: _reload, child: const Text('Ponów')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final recurring = _map(data['recurring']);
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _result;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _monthSelector(),
              const SizedBox(height: 14),
              _sectionTitle(
                'Faktury miesięczne',
                'Zaznacz klientów, którzy razem z Fakturą VAT mają dostać wszystkie WZ z rozliczenia.',
              ),
              const SizedBox(height: 8),
              if (_list(recurring['rows']).isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Brak WZ do faktur miesięcznych w tym miesiącu.',
                    ),
                  ),
                )
              else
                ..._list(recurring['rows']).map(_recurringClientCard),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    ),
  );

  Widget _monthSelector() => Row(
    children: [
      IconButton(
        tooltip: 'Poprzedni miesiąc',
        onPressed: () {
          setState(() {
            _month = DateTime(_month.year, _month.month - 1);
            _result = _load();
          });
        },
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(DateFormat('MM/yyyy').format(_month)),
        ),
      ),
      IconButton(
        tooltip: 'Następny miesiąc',
        onPressed: () {
          setState(() {
            _month = DateTime(_month.year, _month.month + 1);
            _result = _load();
          });
        },
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _recurringClientCard(Map<String, dynamic> client) {
    final id = _int(client['client_id']);
    final saving = _savingPreferences.contains(id);
    final enabled = client['email_monthly_wz_with_invoice'] == true;
    final hasEmail = client['email']?.toString().trim().isNotEmpty == true;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(client['name']?.toString() ?? 'Klient'),
        subtitle: Text(
          '${client['documents_count'] ?? 0} WZ · ${client['email']?.toString().isNotEmpty == true ? client['email'] : 'brak e-maila'}',
        ),
        children: [
          SwitchListTile(
            value: enabled,
            onChanged: saving || !hasEmail
                ? null
                : (value) => _setPreference(client, value),
            title: const Text('Wyślij wszystkie WZ razem z Fakturą VAT'),
            subtitle: saving
                ? const Text('Zapisywanie…')
                : (!hasEmail
                      ? const Text('Najpierw uzupełnij adres e-mail klienta.')
                      : null),
          ),
          _clientDetails(client),
        ],
      ),
    );
  }

  Widget _clientDetails(Map<String, dynamic> client) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const Text('Produkty', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        ..._list(client['products']).map(
          (product) => Text(
            '${product['name'] ?? 'Produkt'} — ${_number(product['quantity'])} szt.',
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Wystawione WZ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        ..._list(client['documents']).map(
          (document) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(document['number']?.toString() ?? 'WZ'),
            subtitle: Text(
              [
                document['date'],
                document['location'],
                document['final_invoice_number'] == null
                    ? null
                    : 'FV: ${document['final_invoice_number']}',
              ].whereType<Object>().join(' · '),
            ),
            trailing: IconButton(
              tooltip: 'Podgląd WZ',
              onPressed: _busyDocumentId == _int(document['id'])
                  ? null
                  : () => _openWz(document),
              icon: _busyDocumentId == _int(document['id'])
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 3),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false)
    : const <Map<String, dynamic>>[];

int _int(dynamic value) => int.tryParse('$value') ?? 0;
double _double(dynamic value) => double.tryParse('$value') ?? 0;
String _number(dynamic value) {
  final number = _double(value);
  return number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toStringAsFixed(2).replaceAll('.', ',');
}
