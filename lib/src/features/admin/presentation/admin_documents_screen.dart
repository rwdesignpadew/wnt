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
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;

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
          .documents(token, page: nextPage);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _hasMore = items.length == 30;
        final keys = _additionalDocuments
            .map((item) => '${item['source']}:${item['id']}')
            .toSet();
        _additionalDocuments.addAll(
          items.where((item) => keys.add('${item['source']}:${item['id']}')),
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
    await ref.refresh(adminDocumentsProvider.future);
  }

  Future<void> _delete(Map<String, dynamic> document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć WZ?'),
        content: Text(
          '${document['title'] ?? 'WZ'} zostanie usunięta z aplikacji i Fakturowni. Stany magazynowe oraz zwroty zostaną odwrócone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń WZ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = _int(document['id']);
    setState(() => _busy = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .deleteDocument(token, id);
      ref.invalidate(adminDocumentsProvider);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wystawić Fakturę VAT?'),
        content: Text(
          'Faktura zostanie wystawiona do ${document['title'] ?? 'wybranego WZ'} i wysłana do Fakturowni.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wystaw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = _int(document['id']);
    setState(() => _busy = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final response = await ref
          .read(adminRepositoryProvider)
          .createFinalInvoice(token, id);
      ref.invalidate(adminDocumentsProvider);
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
      final pdf = document['source'] == 'fakturownia'
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
      ref.invalidate(adminDocumentsProvider);
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

  @override
  Widget build(BuildContext context) => ref
      .watch(adminDocumentsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminDocumentsProvider),
        ),
        data: (items) {
          final allByKey = <String, Map<String, dynamic>>{
            for (final item in [...items, ..._additionalDocuments])
              '${item['source']}:${item['id']}': item,
          };
          final sorted = allByKey.values.toList()..sort((a, b) {
            final byDate = _documentSortAt(
              b,
            ).compareTo(_documentSortAt(a));
            if (byDate != 0) return byDate;
            if (a['type'] == 'invoice' && b['type'] != 'invoice') return -1;
            if (b['type'] == 'invoice' && a['type'] != 'invoice') return 1;
            return _int(b['id']).compareTo(_int(a['id']));
          });
          final documents = sorted.where((document) {
            if (_filter == 'wz') return document['type'] == 'wz';
            if (_filter == 'invoice') return document['type'] == 'invoice';
            return true;
          }).toList();
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
                    const SizedBox(height: 12),
                    _DocumentFilters(
                      selected: _filter,
                      onChanged: (value) => setState(() => _filter = value),
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
                  subtitle: Text(
                    '${document['type'] == 'invoice' ? 'Faktura VAT' : document['type'] == 'pz' ? 'PZ' : 'WZ'} · '
                    '${document['display_date'] ?? ''} · ${document['subtitle'] ?? ''} · ${document['meta'] ?? ''}',
                  ),
                  trailing: _busy == _int(document['id'])
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            if (document['source'] == 'local' &&
                                (document['can_invoice'] == true ||
                                    document['can_delete'] == true))
                              PopupMenuButton<String>(
                                tooltip: 'Więcej działań',
                                onSelected: (action) {
                                  if (action == 'invoice') {
                                    _invoice(document);
                                  } else if (action == 'delete') {
                                    _delete(document);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (document['can_invoice'] == true)
                                    const PopupMenuItem(
                                      value: 'invoice',
                                      child: Text('Wystaw Fakturę VAT'),
                                    ),
                                  if (document['can_delete'] == true)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Usuń WZ'),
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

class _DocumentFilters extends StatelessWidget {
  const _DocumentFilters({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'Wszystkie'),
      ('wz', 'WZ'),
      ('invoice', 'Faktury VAT'),
    ];
    return Container(
      width: double.infinity,
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: WntColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WntColors.line),
      ),
      child: Row(
        children: [
          for (final filter in filters)
            Expanded(
              child: Material(
                color: selected == filter.$1 ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(filter.$1),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        filter.$2,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected == filter.$1
                              ? WntColors.brand
                              : WntColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

int _int(dynamic value) => int.tryParse('$value') ?? 0;

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
