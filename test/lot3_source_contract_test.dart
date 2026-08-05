import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('lot 3 adds manual location search and visual sliders', () {
    final nearby = _read('lib/features/home/nearby_page.dart');
    final service = _read('lib/features/home/nearby_location_service.dart');
    final fuel = _read('lib/features/fuel_prices/fuel_price_compare_page.dart');
    final charging = _read(
      'lib/features/charging_prices/charging_compare_page.dart',
    );
    final parking = _read('lib/features/parking/parking_page.dart');
    final controls = _read(
      'lib/features/technical_control/technical_control_compare_page.dart',
    );

    expect(nearby, contains('Ville, code postal ou adresse'));
    expect(nearby, contains('Un garage automobile'));
    expect(service, contains('data.geopf.fr'));
    expect(service, contains("'/geocodage/search'"));
    expect(fuel, contains("ValueKey('fuel-radius-slider')"));
    expect(charging, contains("ValueKey('charging-power-slider')"));
    expect(parking, contains("ValueKey('parking-radius-slider')"));
    expect(controls, contains("ValueKey('technical-control-radius-slider')"));
  });

  test('lot 3 consolidates documents reminders and classification', () {
    final form = _read(
      'lib/features/vehicle_care/vehicle_event_form_page.dart',
    );
    final notifications = _read(
      'lib/features/vehicle_care/vehicle_event_notification_service.dart',
    );
    final care = _read('lib/features/vehicle_care/vehicle_care_page.dart');
    final catalog = _read(
      'lib/features/vehicle_care/vehicle_event_catalog.dart',
    );
    final analysis = _read('lib/features/documents/analysis_result_page.dart');

    expect(form, contains("ValueKey('event-preview-document')"));
    expect(form, contains("ValueKey('event-remove-document')"));
    expect(notifications, contains('synchronizeReminders'));
    expect(notifications, contains('vehicleEventNotificationPayloadPrefix'));
    expect(notifications, contains('vehicleEventNotificationPayload('));
    expect(care, contains('_synchronizeEventReminders'));
    expect(catalog, contains("code: 'ANTI_POLLUTION'"));
    expect(catalog, contains("code: 'DIAGNOSTICS'"));
    expect(catalog, contains("code: 'PURCHASE_SALE'"));
    expect(analysis, contains("ValueKey('analysis-event-category')"));
    expect(analysis, contains('categoryCode: details.categoryCode'));
  });
}
