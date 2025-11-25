import 'package:flutter/material.dart';
import 'package:hook_app/app/theme.dart';
import 'package:hook_app/app/routes.dart';

class HookUpApp extends StatelessWidget {
  const HookUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HookUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: Routes.loading,
      onGenerateRoute: Routes.generateRoute,
    );
  }
}
