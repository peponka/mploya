// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class JitsiEmbed extends StatefulWidget {
  final String roomUrl;
  final String displayName;
  final VoidCallback? onCallEnded;

  const JitsiEmbed({super.key, required this.roomUrl, required this.displayName, this.onCallEnded});

  @override
  State<JitsiEmbed> createState() => _JitsiEmbedState();
}

class _JitsiEmbedState extends State<JitsiEmbed> {
  late final String _viewId;
  static final _registered = <String>{};

  @override
  void initState() {
    super.initState();
    _viewId = 'daily-${widget.roomUrl.hashCode}';
    if (!_registered.contains(_viewId)) {
      _registered.add(_viewId);
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
        final iframe = html.IFrameElement()
          ..src = widget.roomUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..setAttribute('allow', 'camera; microphone; fullscreen; display-capture; autoplay');
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
