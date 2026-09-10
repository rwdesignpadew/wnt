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
import '../application/driver_providers.dart';
import 'driver_service_screen.dart';

class DriverDocumentsScreen extends ConsumerStatefulWidget {
  const DriverDocumentsScreen({super.key});
  @override
  ConsumerState<DriverDocumentsScreen> createState() =>
      _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends ConsumerState<DriverDocumentsScreen> {
  String? _busyKey;

  Future<void> _open(Map<String, dynamic> document) async {
    final id = _int(document['id']);
    final type = (document['type'] ?? document['kind'] ?? 'wz')
        .toString()
        .toLowerCase();
    final busyKey = '$type:$id';
    setState(() => _busyKey = busyKey);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(driverRepositoryProvider);
      final pdf = type == 'pz'
          ? await repository.documentPreview(token, id)
          : await repository.documentPdf(token, id);
      if (pdf.contentType.contains('text/html')) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HtmlDocumentScreen(
              html: utf8.decode(pdf.bytes),
              title: document['number']?.toString() ?? 'PZ',
            ),
          ),
        );
        return;
      }
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}${type.toUpperCase()}-$id.pdf',
      );
      await file.writeAsBytes(pdf.bytes, flush: true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfDocumentScreen(
            path: file.path,
            title: document['number']?.toString() ?? 'WZ',
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
      if (mounted && _busyKey == busyKey) setState(() => _busyKey = null);
    }
  }

  Future<void> _correct(
    Map<String, dynamic> document,
    List<Map<String, dynamic>> products,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DriverServiceScreen(document: document, products: products),
      ),
    );
    ref.invalidate(driverRouteProvider);
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(driverRouteProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(driverRouteProvider),
          ),
          data: (data) {
            final products = _list(data['products']);
            final documents = driverDocumentRows(data['documents']);
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(driverRouteProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Dokumenty WZ i PZ',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (documents.isEmpty)
                    const EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Brak dokumentów',
                      message:
                          'Wystawione dokumenty z dzisiejszej trasy pojawią się tutaj.',
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < documents.length;
                            index++
                          ) ...[
                            ListTile(
                              leading: Icon(
                                _documentType(documents[index]) == 'pz'
                                    ? Icons.inventory_2_outlined
                                    : Icons.description_outlined,
                                color: WntColors.brand,
                              ),
                              title: Text(
                                documents[index]['number'].toString(),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (_map(
                                              documents[index]['client'],
                                            )?['name'] ??
                                            '')
                                        .toString(),
                                  ),
                                  Text(
                                    '${documents[index]['email_sent_at'] ?? ''}'
                                            .trim()
                                            .isNotEmpty
                                        ? 'Wysłano: ${(documents[index]['email_recipients'] as List<dynamic>? ?? const <dynamic>[]).join(', ')}'
                                        : 'Nie wysłano',
                                    style: TextStyle(
                                      color:
                                          '${documents[index]['email_sent_at'] ?? ''}'
                                              .trim()
                                              .isNotEmpty
                                          ? Colors.green.shade700
                                          : WntColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              trailing:
                                  _busyKey == _documentKey(documents[index])
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 2,
                                      children: [
                                        if (_documentType(documents[index]) ==
                                            'wz')
                                          IconButton(
                                            tooltip: 'Korekta WZ',
                                            onPressed: () => _correct(
                                              documents[index],
                                              products,
                                            ),
                                            icon: const Icon(
                                              Icons.edit_document,
                                              color: WntColors.brand,
                                            ),
                                          ),
                                        IconButton(
                                          tooltip:
                                              'Podgląd ${_documentType(documents[index]).toUpperCase()}',
                                          onPressed: () =>
                                              _open(documents[index]),
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            if (index < documents.length - 1) const Divider(),
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
Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : null;
int _int(dynamic value) => int.tryParse('$value') ?? 0;

String _documentType(Map<String, dynamic> document) =>
    (document['type'] ?? document['kind'] ?? 'wz').toString().toLowerCase();

String _documentKey(Map<String, dynamic> document) =>
    '${_documentType(document)}:${_int(document['id'])}';

bool _flag(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = '${value ?? ''}'.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

List<Map<String, dynamic>> driverDocumentRows(dynamic value) {
  final rows = <Map<String, dynamic>>[];
  for (final document in _list(value)) {
    final wzNumber = '${document['number'] ?? ''}'.trim();
    if (wzNumber.isEmpty) continue;

    rows.add({...document, 'type': 'wz', 'number': wzNumber});
    final pzNumber = '${document['pz_number'] ?? ''}'.trim();
    if (_flag(document['has_return_pz']) || pzNumber.isNotEmpty) {
      rows.add({
        ...document,
        'type': 'pz',
        'number': pzNumber.isNotEmpty ? pzNumber : 'PZ do $wzNumber',
      });
    }
  }

  rows.sort((a, b) {
    final byDate = _int(b['sort_at']).compareTo(_int(a['sort_at']));
    if (byDate != 0) return byDate;
    final byId = _int(b['id']).compareTo(_int(a['id']));
    if (byId != 0) return byId;
    return _documentType(a) == 'pz' ? 1 : -1;
  });
  return rows;
}
