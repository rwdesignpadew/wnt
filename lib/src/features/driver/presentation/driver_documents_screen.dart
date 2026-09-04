import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/presentation/pdf_document_screen.dart';
import '../application/driver_providers.dart';
import 'driver_service_screen.dart';

class DriverDocumentsScreen extends ConsumerStatefulWidget {
  const DriverDocumentsScreen({super.key});
  @override
  ConsumerState<DriverDocumentsScreen> createState() =>
      _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends ConsumerState<DriverDocumentsScreen> {
  int? _busyId;

  Future<void> _open(Map<String, dynamic> document) async {
    final id = _int(document['id']);
    setState(() => _busyId = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final pdf = await ref
          .read(driverRepositoryProvider)
          .documentPdf(token, id);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}WZ-$id.pdf');
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
      if (mounted) setState(() => _busyId = null);
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
            final documents =
                _list(data['documents'])
                    .where(
                      (document) =>
                          document['number']?.toString().isNotEmpty == true,
                    )
                    .toList()
                  ..sort((a, b) {
                    final byDate = _int(
                      b['sort_at'],
                    ).compareTo(_int(a['sort_at']));
                    return byDate != 0
                        ? byDate
                        : _int(b['id']).compareTo(_int(a['id']));
                  });
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(driverRouteProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Dokumenty WZ',
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
                              leading: const Icon(
                                Icons.description_outlined,
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
                              trailing: _busyId == _int(documents[index]['id'])
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 2,
                                      children: [
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
                                          tooltip: 'Podgląd oryginalnego WZ',
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
