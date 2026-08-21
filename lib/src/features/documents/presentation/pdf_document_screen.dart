import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfDocumentScreen extends StatelessWidget {
  const PdfDocumentScreen({
    super.key,
    required this.path,
    required this.title,
    this.bottomNavigationBar,
  });

  final String path;
  final String title;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Drukuj WZ',
            onPressed: () => Printing.layoutPdf(
              name: _fileName(title),
              onLayout: (_) => File(path).readAsBytes(),
            ),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Pobierz lub udostępnij',
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                files: [XFile(path, mimeType: 'application/pdf')],
                fileNameOverrides: [_fileName(title)],
                subject: title,
              ),
            ),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: const Color(0xFFDEE3EA),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: PDFView(
            filePath: path,
            backgroundColor: const Color(0xFFDEE3EA),
            fitPolicy: FitPolicy.WIDTH,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: false,
            onError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Nie udało się otworzyć PDF: $error')),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  static String _fileName(String title) {
    final safe = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
    return '${safe.isEmpty ? 'dokument' : safe}.pdf';
  }

  static Future<void> removeTemporary(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
