import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'around me is a four-category chooser and location lives in category pages',
    () {
      final nearby = _read('lib/features/home/nearby_page.dart');
      final picker = _read(
        'lib/features/home/nearby_location_picker_card.dart',
      );
      final pages = [
        _read('lib/features/fuel_prices/fuel_price_compare_page.dart'),
        _read('lib/features/charging_prices/charging_compare_page.dart'),
        _read('lib/features/parking/parking_page.dart'),
        _read(
          'lib/features/technical_control/technical_control_compare_page.dart',
        ),
      ];

      expect(nearby, isNot(contains('Un garage automobile')));
      expect(nearby, isNot(contains('Ville, code postal ou adresse')));
      expect(picker, contains('Où voulez-vous chercher ?'));
      expect(picker, contains("ValueKey('category-address-field')"));
      for (final page in pages) {
        expect(page, contains('NearbyLocationPickerCard('));
      }
    },
  );

  test('home and onboarding use the commercial V1 language', () {
    final home = _read('lib/features/home/home_page.dart');
    final onboarding = _read('lib/features/onboarding/onboarding_page.dart');
    final router = _read('lib/core/router/app_router.dart');

    expect(home, contains('Votre copilote AutoClair'));
    expect(home, contains('Vos raccourcis'));
    expect(home, isNot(contains("title: 'Mes économies'")));
    expect(home, isNot(contains("title: 'Tous les outils'")));
    expect(home, isNot(contains('Moments clés')));
    expect(onboarding, contains("ValueKey('onboarding-road')"));
    expect(onboarding, contains('_JourneyRoadPainter'));
    expect(router, contains("path: '/savings'"));
    expect(router, contains("redirect: (context, state) => '/home'"));
  });

  test('maintenance and recalls are presented as user-level decisions', () {
    final helper = _read(
      'lib/features/vehicle_care/vehicle_maintenance_presentation.dart',
    );
    final care = _read('lib/features/vehicle_care/vehicle_care_page.dart');
    final assistant = _read(
      'lib/features/vehicle_care/vehicle_assistant_brief.dart',
    );

    expect(helper, contains("return 'Révision avec vidange'"));
    expect(care, contains('VehicleMaintenanceGroup'));
    expect(care, contains('Cela ne confirme pas que ce véhicule est concerné'));
    expect(care, contains('Véhicule non concerné'));
    expect(assistant, contains("recall.status.toUpperCase() == 'SCHEDULED'"));
    expect(care, contains('Scrollable.ensureVisible('));
  });
}
