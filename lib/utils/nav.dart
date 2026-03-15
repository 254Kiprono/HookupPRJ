import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';

class Nav {
  static void safePop(BuildContext context, {String fallback = Routes.home}) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(fallback);
    }
  }
}
