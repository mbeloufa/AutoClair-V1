import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class AutoClairApp extends StatefulWidget {
  const AutoClairApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<AutoClairApp> createState() => _AutoClairAppState();
}

class _AutoClairAppState extends State<AutoClairApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.controller);
  }

  @override
  void dispose() {
    _router.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AutoClair',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
