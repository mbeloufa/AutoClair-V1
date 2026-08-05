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
    required String eventKey,
    required String vehicleLabel,
    required String eventTitle,
    required DateTime eventDate,
    required int daysBefore,
  }) async {
    final reminderAt = vehicleEventReminderAt(
      eventDate: eventDate,
      daysBefore: daysBefore,
    );
    if (!reminderAt.isAfter(DateTime.now())) {
      throw const VehicleEventNotificationException(
        'La date choisie est trop proche pour ce délai de rappel.',
      );
    }

    await ensurePermission();

    final scheduledDate = tz.TZDateTime.from(reminderAt, tz.local);
    await _plugin.zonedSchedule(
      vehicleEventNotificationId(eventKey),
      'Rappel AutoClair',
      '$eventTitle · $vehicleLabel',
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
      payload: 'vehicle-event:$eventKey',
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
