import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/wnt_colors.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/presentation/pdf_document_screen.dart';
import '../application/client_providers.dart';

class ClientDocumentsScreen extends ConsumerStatefulWidget {
  const ClientDocumentsScreen({super.key});

  @override
  ConsumerState<ClientDocumentsScreen> createState() =>
      _ClientDocumentsScreenState();
}

class _ClientDocumentsScreenState extends ConsumerState<ClientDocumentsScreen> {
  int? _loadingId;

  Future<void> _open(
    Map<String, dynamic> document, {
    required bool save,
  }) async {
    final id = int.tryParse(document['id']?.toString() ?? '') ?? 0;
    if (id == 0) return;
    setState(() => _loadingId = id);
    try {
      final token = ref.read(authControllerProvider).session!.token;
      final repository = ref.read(clientRepositoryProvider);
      final download = document['source'] == 'fakturownia'
          ? await repository.externalDocumentPdf(token, id)
          : await repository.documentPdf(token, id);
      final directory = save
          ? (await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory())
          : await getTemporaryDirectory();
      final safeName = _safeFilename(
        download.filename == 'dokument.pdf'
            ? '${document['number'] ?? 'dokument'}.pdf'
            : download.filename,
      );
      final file = File('${directory.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(download.bytes, flush: true);
      if (!mounted) return;
      if (save) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zapisano dokument: ${file.path}')),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfDocumentScreen(
              path: file.path,
              title: document['number']?.toString() ?? 'Dokument',
            ),
          ),
        );
        await PdfDocumentScreen.removeTemporary(file.path);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: WntColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(clientDocumentsProvider);
    return documents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(clientDocumentsProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(clientDocumentsProvider),
        child: items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Brak dokumentów',
                    message:
                        'WZ i Faktury VAT pojawią się tutaj po wystawieniu.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Dokumenty',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    );
                  }
                  final document = items[index - 1];
                  final id =
                      int.tryParse(document['id']?.toString() ?? '') ?? 0;
                  final total =
                      double.tryParse(document['total']?.toString() ?? '') ?? 0;
                  final busy = _loadingId == id;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: WntColors.brand,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document['number']?.toString().isNotEmpty ==
                                          true
                                      ? document['number'].toString()
                                      : 'Dokument bez numeru',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  document['type'] == 'invoice'
                                      ? 'Faktura VAT'
                                      : 'WZ',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: WntColors.brand),
                                ),
                                Text(
                                  '${document['planned_at'] ?? ''} · ${NumberFormat.currency(locale: 'pl_PL', symbol: 'zł').format(total)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: WntColors.muted),
                                ),
                              ],
                            ),
                          ),
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else ...[
                            IconButton(
                              tooltip: 'Podgląd PDF',
                              onPressed: () => _open(document, save: false),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            IconButton(
                              tooltip: 'Pobierz PDF',
                              onPressed: () => _open(document, save: true),
                              icon: const Icon(Icons.download_outlined),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

String _safeFilename(String value) =>
    value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
