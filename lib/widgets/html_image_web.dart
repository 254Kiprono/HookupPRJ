import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class HtmlImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const HtmlImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final String viewId = 'html-image-${url.hashCode}';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      final img = html.ImageElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain'
        ..style.border = 'none';
      return img;
    });

    return HtmlElementView(viewType: viewId);
  }
}
