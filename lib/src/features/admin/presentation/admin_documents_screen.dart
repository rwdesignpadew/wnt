import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/presentation/pdf_document_screen.dart';
import '../../documents/presentation/html_document_screen.dart';
import '../../driver/application/driver_providers.dart';
import '../../driver/presentation/driver_manual_wz_screen.dart';
import '../../driver/presentation/driver_service_screen.dart';
import '../application/admin_providers.dart';

class AdminDocumentsScreen extends ConsumerStatefulWidget {
  const AdminDocumentsScreen({super.key});
  @override
  ConsumerState<AdminDocumentsScreen> createState() =>
      _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends ConsumerState<AdminDocumentsScreen> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _additionalDocuments = [];
  int? _busy;
  String _filter = 'all';
  String _search = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _source = 'all';
  int? _clientId;
  String _clientType = 'all';
  int? _driverId;
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;

  AdminDocumentsQuery get _query => (
    type: _filter,
    search: _search,
    dateFrom: _dateFrom == null ? null : _isoDate(_dateFrom!),
    dateTo: _dateTo == null ? null : _isoDate(_dateTo!),
    source: _source,
    clientId: _clientId,
    clientType: _clientType,
    driverId: _driverId,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final nextPage = _page + 1;
      final items = await ref
          .read(adminRepositoryProvider)
          .documents(
            token,
            page: nextPage,
            type: _filter,
            search: _search,
            dateFrom: _dateFrom == null ? null : _isoDate(_dateFrom!),
            dateTo: _dateTo == null ? null : _isoDate(_dateTo!),
            source: _source,
            clientId: _clientId,
            clientType: _clientType,
            driverId: _driverId,
          );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _hasMore = items.length == 30;
        final keys = _additionalDocuments
            .map((item) => '${item['source']}:${item['type']}:${item['id']}')
            .toSet();
        _additionalDocuments.addAll(
          items.where(
            (item) =>
                keys.add('${item['source']}:${item['type']}:${item['id']}'),
          ),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refreshDocuments() async {
    setState(() {
      _page = 1;
      _hasMore = true;
      _additionalDocuments.clear();
    });
    ref.invalidate(adminDocumentsProvider(_query));
    await ref.read(adminDocumentsProvider(_query).future);
  }

  Future<void> _openManualWz() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DriverManualWzScreen()),
    );
    if (saved == true && mounted) await _refreshDocuments();
  }

  Future<void> _correctWz(Map<String, dynamic> document) async {
    final documentId = _int(document['id']);
    if (documentId < 1) return;
    setState(() => _busy = documentId);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(driverRepositoryProvider)
          .serviceDocument(token, documentId);
      if (!mounted) return;
      final rawDocument = response['document'];
      final rawProducts = response['products'];
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverServiceScreen(
            document: rawDocument is Map
                ? rawDocument.cast<String, dynamic>()
                : const <String, dynamic>{},
            products: rawProducts is List
                ? rawProducts
                      .whereType<Map>()
                      .map((item) => item.cast<String, dynamic>())
                      .toList()
                : const <Map<String, dynamic>>[],
          ),
        ),
      );
      if (mounted) await _refreshDocuments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _selectInvoiceDocument(
    List<Map<String, dynamic>> documents,
  ) async {
    final eligible = documents
        .where(
          (document) =>
              document['source'] == 'local' &&
              document['type'] == 'wz' &&
              document['can_invoice'] == true,
        )
        .toList();
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generuj Fakturę VAT'),
        content: SizedBox(
          width: 560,
          child: eligible.isEmpty
              ? const Text('Brak WZ oczekujących na Fakturę VAT.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: eligible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final document = eligible[index];
                    return ListTile(
                      title: Text('${document['title'] ?? 'WZ'}'),
                      subtitle: Text(
                        '${document['subtitle'] ?? ''} · ${document['display_date'] ?? ''}',
                      ),
                      trailing: Text('${document['meta'] ?? ''}'),
                      onTap: () => Navigator.pop(dialogContext, document),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) await _invoice(selected);
  }

  Future<void> _delete(Map<String, dynamic> document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć dokument?'),
        content: Text(
          '${document['title'] ?? 'Dokument'} zostanie usunięty z aplikacji i Fakturowni. Tej operacji nie można cofnąć.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń dokument'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = _int(document['id']);
    setState(() => _busy = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      final response = document['source'] == 'local'
          ? await repository.deleteDocument(token, id)
          : await repository.deleteExternalDocument(token, id);
      ref.invalidate(adminDocumentsProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${response['message'] ?? 'WZ usunięta.'}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _invoice(Map<String, dynamic> document) async {
    final serviceItems = (document['service_items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final serviceControllers = <String, TextEditingController>{
      for (final item in serviceItems) '${item['id']}': TextEditingController(),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Wystawić Fakturę VAT?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Faktura zostanie wystawiona do ${document['title'] ?? 'wybranego WZ'} i wysłana do Fakturowni.',
                ),
                if (serviceItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'WZ pozostaje z ceną 0 zł. Podaj cenę netto serwisu wyłącznie na Fakturę VAT.',
                  ),
                  const SizedBox(height: 12),
                  for (final item in serviceItems) ...[
                    TextField(
                      controller: serviceControllers['${item['id']}'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Cena netto - ${item['name'] ?? 'Serwis'}',
                        suffixText: 'zł',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                final valid = serviceControllers.values.every(
                  (controller) =>
                      (double.tryParse(controller.text.replaceAll(',', '.')) ??
                          0) >
                      0,
                );
                if (!valid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Podaj cenę netto za serwis.'),
                    ),
                  );
                  setDialogState(() {});
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Wystaw'),
            ),
          ],
        ),
      ),
    );
    final servicePrices = <String, double>{
      for (final entry in serviceControllers.entries)
        entry.key: double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0,
    };
    for (final controller in serviceControllers.values) {
      controller.dispose();
    }
    if (confirmed != true || !mounted) return;
    final id = _int(document['id']);
    setState(() => _busy = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .createFinalInvoice(token, id, servicePrices: servicePrices);
      ref.invalidate(adminDocumentsProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ??
                  'Faktura VAT została wystawiona.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _open(Map<String, dynamic> document) async {
    final id = _int(document['id']);
    setState(() => _busy = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(adminRepositoryProvider);
      final type = (document['type'] ?? document['kind'] ?? '')
          .toString()
          .toLowerCase();
      final pdf = type == 'pz' && document['source'] != 'fakturownia'
          ? await repository.documentPreview(token, id)
          : document['source'] == 'fakturownia'
          ? await repository.externalDocumentPdf(token, id)
          : await repository.documentPdf(token, id);
      if (pdf.contentType.contains('text/html')) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HtmlDocumentScreen(
              html: utf8.decode(pdf.bytes),
              title: document['title']?.toString() ?? 'Dokument',
            ),
          ),
        );
        return;
      }
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}dokument-$id.pdf',
      );
      await file.writeAsBytes(pdf.bytes, flush: true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfDocumentScreen(
            path: file.path,
            title: document['title']?.toString() ?? 'Dokument',
          ),
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
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _sendToKsef(Map<String, dynamic> document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wysłać do KSeF?'),
        content: Text(
          '${document['title'] ?? 'Faktura VAT'} zostanie wysłana przez Fakturownię do KSeF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Wyślij'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final finalConfirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: WntColors.error),
        title: const Text('Ostateczne potwierdzenie'),
        content: const Text(
          'Wysłanie nada fakturze oficjalny numer KSeF i nie można go cofnąć. Czy na pewno kontynuować?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nie wysyłaj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WntColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Potwierdzam wysyłkę'),
          ),
        ],
      ),
    );
    if (finalConfirmation != true || !mounted) return;
    final id = _int(document['id']);
    setState(() => _busy = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .sendInvoiceToKsef(token, id);
      ref.invalidate(adminDocumentsProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${response['message'] ?? 'Wysłano do KSeF.'}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _emailDocument(Map<String, dynamic> document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wysłać dokument do klienta?'),
        content: Text(
          '${document['title'] ?? 'Dokument'} zostanie wysłany zgodnie z ustawieniami odbiorców przypisanymi do klienta i lokalizacji.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Wyślij'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = _int(document['id']);
    setState(() => _busy = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final message = await ref
          .read(adminRepositoryProvider)
          .emailDocument(token, id);
      await _refreshDocuments();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  int get _activeFilterCount =>
      (_filter == 'all' ? 0 : 1) +
      (_search.trim().isEmpty ? 0 : 1) +
      (_dateFrom == null ? 0 : 1) +
      (_dateTo == null ? 0 : 1) +
      (_source == 'all' ? 0 : 1) +
      (_clientId == null ? 0 : 1) +
      (_clientType == 'all' ? 0 : 1) +
      (_driverId == null ? 0 : 1);

  Future<void> _openFilters() async {
    final token = ref.read(authControllerProvider).session!.token;
    Map<String, dynamic> options;
    try {
      options = await ref
          .read(adminRepositoryProvider)
          .documentFilterOptions(token);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: WntColors.error),
      );
      return;
    }
    if (!mounted) return;
    final clients = (options['clients'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
    final drivers = (options['drivers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
    final search = TextEditingController(text: _search);
    var type = _filter;
    var dateFrom = _dateFrom;
    var dateTo = _dateTo;
    var source = _source;
    var clientId = _clientId;
    var clientType = _clientType;
    var driverId = _driverId;
    final result = await showModalBottomSheet<_DocumentFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtry dokumentów',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Numer dokumentu, klient lub NIP',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Rodzaj dokumentu',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Wszystkie dokumenty'),
                    ),
                    DropdownMenuItem(value: 'wz', child: Text('WZ / PZ')),
                    DropdownMenuItem(
                      value: 'invoice',
                      child: Text('Tylko Faktury VAT'),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => type = value ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: source,
                  decoration: const InputDecoration(labelText: 'Źródło'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Wszystkie')),
                    DropdownMenuItem(value: 'local', child: Text('Aplikacja')),
                    DropdownMenuItem(
                      value: 'fakturownia',
                      child: Text('Fakturownia'),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => source = value ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: clientId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Klient'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Wszyscy klienci'),
                    ),
                    ...clients.map(
                      (client) => DropdownMenuItem<int?>(
                        value: _int(client['id']),
                        child: Text(
                          client['name']?.toString() ?? 'Klient',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => clientId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: clientType,
                  decoration: const InputDecoration(labelText: 'Typ klienta'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Wszyscy')),
                    DropdownMenuItem(value: 'company', child: Text('Firmy')),
                    DropdownMenuItem(
                      value: 'private',
                      child: Text('Osoby prywatne'),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => clientType = value ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: driverId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kierowca / wystawca',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Wszyscy kierowcy'),
                    ),
                    ...drivers.map(
                      (driver) => DropdownMenuItem<int?>(
                        value: _int(driver['id']),
                        child: Text(
                          driver['name']?.toString() ?? 'Kierowca',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => driverId = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FilterDateTile(
                        label: 'Data od',
                        value: dateFrom,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 366),
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() => dateFrom = picked);
                          }
                        },
                        onClear: dateFrom == null
                            ? null
                            : () => setSheetState(() => dateFrom = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FilterDateTile(
                        label: 'Data do',
                        value: dateTo,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 366),
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() => dateTo = picked);
                          }
                        },
                        onClear: dateTo == null
                            ? null
                            : () => setSheetState(() => dateTo = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          const _DocumentFilterResult(),
                        ),
                        child: const Text('Wyczyść'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          _DocumentFilterResult(
                            type: type,
                            search: search.text.trim(),
                            dateFrom: dateFrom,
                            dateTo: dateTo,
                            source: source,
                            clientId: clientId,
                            clientType: clientType,
                            driverId: driverId,
                          ),
                        ),
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('Zastosuj'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    search.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.type;
      _search = result.search;
      _dateFrom = result.dateFrom;
      _dateTo = result.dateTo;
      _source = result.source;
      _clientId = result.clientId;
      _clientType = result.clientType;
      _driverId = result.driverId;
      _page = 1;
      _hasMore = true;
      _additionalDocuments.clear();
    });
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(adminDocumentsProvider(_query))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminDocumentsProvider(_query)),
        ),
        data: (items) {
          final allByKey = <String, Map<String, dynamic>>{
            for (final item in [...items, ..._additionalDocuments])
              '${item['source']}:${item['type']}:${item['id']}': item,
          };
          final sorted = allByKey.values.toList()
            ..sort((a, b) {
              final byDate = _documentSortAt(b).compareTo(_documentSortAt(a));
              if (byDate != 0) return byDate;
              if (a['type'] == 'invoice' && b['type'] != 'invoice') return -1;
              if (b['type'] == 'invoice' && a['type'] != 'invoice') return 1;
              return _int(b['id']).compareTo(_int(a['id']));
            });
          final documents = sorted;
          return RefreshIndicator(
            onRefresh: _refreshDocuments,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: documents.length + 1 + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dokumenty',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectInvoiceDocument(sorted),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Generuj Fakturę VAT'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _openManualWz,
                              icon: const Icon(Icons.add),
                              label: const Text('Generuj WZ'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openFilters,
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: Text(
                            _activeFilterCount == 0
                                ? 'Filtry'
                                : 'Filtry ($_activeFilterCount)',
                          ),
                        ),
                      ),
                    ],
                  );
                }
                if (_loadingMore && index == documents.length + 1) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final document = documents[index - 1];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.description_outlined,
                      color: WntColors.brand,
                    ),
                    title: Text(
                      document['title']?.toString().isNotEmpty == true
                          ? document['title'].toString()
                          : 'Dokument bez numeru',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${document['type'] == 'invoice'
                              ? 'Faktura VAT'
                              : document['type'] == 'pz'
                              ? 'PZ'
                              : 'WZ'} · '
                          '${document['display_date'] ?? ''} · ${document['subtitle'] ?? ''} · ${document['meta'] ?? ''}',
                        ),
                        if (document['type'] == 'wz' ||
                            document['type'] == 'pz')
                          Text(
                            '${document['email_sent_at'] ?? ''}'
                                    .trim()
                                    .isNotEmpty
                                ? 'Wysłano: ${(document['email_recipients'] as List<dynamic>? ?? const <dynamic>[]).join(', ')}'
                                : 'Nie wysłano',
                            style: TextStyle(
                              color:
                                  '${document['email_sent_at'] ?? ''}'
                                      .trim()
                                      .isNotEmpty
                                  ? Colors.green.shade700
                                  : WntColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    trailing: _busy == _int(document['id'])
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((document['type'] == 'wz' ||
                                      document['type'] == 'pz') &&
                                  document['source'] != 'fakturownia' &&
                                  _int(document['id']) > 0)
                                IconButton(
                                  tooltip: 'Wyślij dokument do klienta',
                                  onPressed: () => _emailDocument(document),
                                  icon: const Icon(
                                    Icons.send_outlined,
                                    color: WntColors.brand,
                                  ),
                                ),
                              if (document['can_send_to_ksef'] == true)
                                IconButton(
                                  tooltip: 'Wyślij do KSeF',
                                  onPressed: () => _sendToKsef(document),
                                  icon: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: WntColors.brand,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Podgląd oryginalnego PDF',
                                onPressed: document['can_preview'] == false
                                    ? null
                                    : () => _open(document),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              if ((document['source'] == 'local' &&
                                      document['type'] == 'wz' &&
                                      _int(document['id']) > 0) ||
                                  document['can_invoice'] == true ||
                                  document['can_delete'] == true)
                                PopupMenuButton<String>(
                                  tooltip: 'Więcej działań',
                                  onSelected: (action) {
                                    if (action == 'invoice') {
                                      _invoice(document);
                                    } else if (action == 'correct') {
                                      _correctWz(document);
                                    } else if (action == 'delete') {
                                      _delete(document);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (document['source'] == 'local' &&
                                        document['type'] == 'wz' &&
                                        _int(document['id']) > 0)
                                      const PopupMenuItem(
                                        value: 'correct',
                                        child: Text('Koryguj WZ'),
                                      ),
                                    if (document['can_invoice'] == true)
                                      const PopupMenuItem(
                                        value: 'invoice',
                                        child: Text('Wystaw Fakturę VAT'),
                                      ),
                                    if (document['can_delete'] == true)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Usuń dokument'),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                  ),
                );
              },
            ),
          );
        },
      );
}

class _DocumentFilterResult {
  const _DocumentFilterResult({
    this.type = 'all',
    this.search = '',
    this.dateFrom,
    this.dateTo,
    this.source = 'all',
    this.clientId,
    this.clientType = 'all',
    this.driverId,
  });

  final String type;
  final String search;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String source;
  final int? clientId;
  final String clientType;
  final int? driverId;
}

class _FilterDateTile extends StatelessWidget {
  const _FilterDateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: onClear == null
            ? const Icon(Icons.calendar_month_outlined)
            : IconButton(
                tooltip: 'Wyczyść datę',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
      ),
      child: Text(value == null ? 'Dowolna' : _displayDate(value!)),
    ),
  );
}

int _int(dynamic value) => int.tryParse('$value') ?? 0;

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.'
    '${value.year.toString().padLeft(4, '0')}';

int _documentSortAt(Map<String, dynamic> document) {
  final serverValue = int.tryParse('${document['sort_at'] ?? ''}');
  if (serverValue != null && serverValue > 0) return serverValue;
  final value = document['display_date']?.toString().trim() ?? '';
  final match = RegExp(
    r'^(\d{2})\.(\d{2})\.(\d{4})(?:\s+(\d{2}):(\d{2}))?',
  ).firstMatch(value);
  if (match == null) return 0;
  return DateTime(
    int.parse(match.group(3)!),
    int.parse(match.group(2)!),
    int.parse(match.group(1)!),
    int.tryParse(match.group(4) ?? '') ?? 0,
    int.tryParse(match.group(5) ?? '') ?? 0,
  ).millisecondsSinceEpoch;
}
