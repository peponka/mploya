import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JitsiEmbed extends StatefulWidget {
  final String roomUrl;
  final String displayName;
  final VoidCallback? onCallEnded;

  const JitsiEmbed({
    super.key,
    required this.roomUrl,
    required this.displayName,
    this.onCallEnded,
  });

  @override
  State<JitsiEmbed> createState() => _JitsiEmbedState();
}

class _JitsiEmbedState extends State<JitsiEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          if (uri.scheme == 'https' || uri.scheme == 'http') return NavigationDecision.navigate;
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.roomUrl));
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
