import 'package:flutter/material.dart';

class HtmlImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const HtmlImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
