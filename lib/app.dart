import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/vehicle_care/vehicle_event_notification_service.dart';

class AutoClairApp extends StatefulWidget {
  const AutoClairApp({required this.controller, super.key});
  final AppController controller;

  @override
  State<AutoClairApp> createState() => _AutoClairAppState();
}

class _AutoClairAppState extends State<AutoClairApp> {
  late final GoRouter _router;
  StreamSubscription<String>? _notificationClicks;
  StreamSubscription<AuthState>? _authEvents;
  String? _pendingRoute;

  String? _routeForPayload(String payload) {
    final match = RegExp(
      r'^vehicle-(event|smart):([0-9a-fA-F-]{36}):(.+)$',
    ).firstMatch(payload);
    if (match == null) return null;
    final vehicleId = match.group(2)!;
    final section = match.group(1) == 'event' ? 'timeline' : 'alerts';
    return '/vehicles/$vehicleId/care?section=$section';
  }

  void _handleNotification(String payload) {
    final route = _routeForPayload(payload);
    if (route == null) return;
    if (!widget.controller.isAuthenticated) {
      _pendingRoute = route;
      return;
    }
    _router.go(route);
  }

  Future<void> _initializeNotificationRouting() async {
    final notifications = VehicleEventNotificationService.instance;
    _notificationClicks = notifications.notificationPayloads.listen(
      _handleNotification,
    );
    try {
      final coldStart = await notifications.takeInitialNotification();
      if (!mounted) return;
      if (coldStart != null) _handleNotification(coldStart);
    } catch (_) {
      // Notifications are optional; never block app launch.
    }
  }

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.controller);
    _authEvents = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) {
        _router.go('/reset-password');
      }
      if (event.session != null && _pendingRoute != null) {
        final route = _pendingRoute!;
        _pendingRoute = null;
        _router.go(route);
      }
    });
    unawaited(_initializeNotificationRouting());
  }

  @override
  void dispose() {
    _notificationClicks?.cancel();
    _authEvents?.cancel();
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
