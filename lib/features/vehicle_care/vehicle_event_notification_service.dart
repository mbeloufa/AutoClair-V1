import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'vehicle_event_reminder.dart';

class VehicleEventNotificationException implements Exception {
  const VehicleEventNotificationException(this.message);

  final String message;
}

class VehicleEventNotificationService {
  VehicleEventNotificationService._();

  static final VehicleEventNotificationService instance =
      VehicleEventNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> scheduleReminder({
    required String vehicleId,
    required String eventKey,
    required String vehicleLabel,
    required String eventTitle,
    required DateTime eventDate,
    required int daysBefore,
  }) async {
    final plan = VehicleEventReminderPlan(
      vehicleId: vehicleId,
      eventKey: eventKey,
      eventTitle: eventTitle,
      eventDate: eventDate,
      daysBefore: daysBefore,
    );
    if (!plan.isFutureAt(DateTime.now())) {
      throw const VehicleEventNotificationException(
        'La date choisie est trop proche pour ce délai de rappel.',
      );
    }

    await ensurePermission();
    await _schedulePlan(plan, vehicleLabel: vehicleLabel);
  }

  Future<void> synchronizeReminders({
    required String vehicleId,
    required Iterable<VehicleEventReminderPlan> plans,
    required String vehicleLabel,
  }) async {
    await _initialize();

    final now = DateTime.now();
    final futurePlans = plans
        .where((plan) => plan.isFutureAt(now))
        .toList(growable: false);
    final desiredIds = desiredVehicleEventNotificationIds(
      futurePlans,
      now: now,
    );

    final pending = await _plugin.pendingNotificationRequests();
    final scopedPayloadPrefix = vehicleEventNotificationPayloadPrefix(
      vehicleId,
    );
    for (final request in pending) {
      if (request.payload?.startsWith(scopedPayloadPrefix) == true &&
          !desiredIds.contains(request.id)) {
        await _plugin.cancel(request.id);
      }
    }

    if (futurePlans.isEmpty) return;

    for (final plan in futurePlans) {
      await _schedulePlan(plan, vehicleLabel: vehicleLabel);
    }
  }

  Future<void> _schedulePlan(
    VehicleEventReminderPlan plan, {
    required String vehicleLabel,
  }) async {
    final scheduledDate = tz.TZDateTime.from(plan.reminderAt, tz.local);
    await _plugin.zonedSchedule(
      plan.notificationId,
      'Rappel AutoClair',
      '${plan.eventTitle} · $vehicleLabel',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'autoclair_vehicle_events',
          'Rappels véhicule',
          channelDescription: 'Rappels des événements prévus du véhicule',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: vehicleEventNotificationPayload(
        vehicleId: plan.vehicleId,
        eventKey: plan.eventKey,
      ),
    );
  }

  Future<void> ensurePermission() async {
    await _initialize();
    final granted = await _requestPermission();
    if (!granted) {
      throw const VehicleEventNotificationException(
        'Les notifications ne sont pas autorisées sur cet appareil.',
      );
    }
  }

  Future<void> cancelReminder(String eventKey) async {
    await _initialize();
    await _plugin.cancel(vehicleEventNotificationId(eventKey));
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }

    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return true;
  }
}
