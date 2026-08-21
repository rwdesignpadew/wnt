import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlDocumentScreen extends StatefulWidget {
  const HtmlDocumentScreen({required this.html, required this.title, super.key});

  final String html;
  final String title;

  @override
  State<HtmlDocumentScreen> createState() => _HtmlDocumentScreenState();
}

class _HtmlDocumentScreenState extends State<HtmlDocumentScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xffeef1f6))
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(child: WebViewWidget(controller: _controller)),
  );
}
