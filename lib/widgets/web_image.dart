import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hook_app/utils/constants.dart';
import 'html_image_web.dart' if (dart.library.io) 'html_image_unsupported.dart';

Widget platformAwareImage(String url, {BoxFit fit = BoxFit.cover}) {
  final proxiedUrl = AppConstants.getProxiedUrl(url);
  if (kIsWeb) {
    return HtmlImage(url: proxiedUrl, fit: fit);
  } else {
    return Image.network(
      proxiedUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
