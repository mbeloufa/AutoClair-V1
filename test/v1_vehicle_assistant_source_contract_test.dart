import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'V1 vehicle page starts with a prioritized AutoClair assistant brief',
    () {
      final page = _read('lib/features/vehicle_care/vehicle_care_page.dart');
      final brief = _read(
        'lib/features/vehicle_care/vehicle_assistant_brief.dart',
      );
      final card = _read(
        'lib/features/vehicle_care/vehicle_assistant_brief_card.dart',
      );

      expect(page, contains("import 'vehicle_assistant_brief.dart';"));
      expect(page, contains('VehicleAssistantBrief.build('));
      expect(page, contains('VehicleAssistantBriefCard('));
      expect(page, contains('_handleAssistantTarget'));

      expect(
        page.indexOf('VehicleAssistantBriefCard('),
        lessThan(page.indexOf('VehicleCarePrimaryActions(')),
      );

      expect(brief, contains('Rappel constructeur à vérifier'));
      expect(brief, contains('Entretien à rattraper'));
      expect(brief, contains('Kilométrage à renseigner'));
      expect(brief, contains('Une économie est peut-être disponible'));
      expect(brief, contains('.take(3)'));
      expect(card, contains('Votre assistant AutoClair'));
      expect(
        card,
        contains(
          'Basé sur votre carnet, vos échéances, alertes et offres connues.',
        ),
      );
    },
  );

  test(
    'vehicle assistant reuses existing data and adds no paid backend call',
    () {
      final brief = _read(
        'lib/features/vehicle_care/vehicle_assistant_brief.dart',
      );
      final page = _read('lib/features/vehicle_care/vehicle_care_page.dart');

      expect(brief, contains('bundle.dashboard.recalls'));
      expect(brief, contains('bundle.dashboard.risks'));
      expect(brief, contains('bundle.schedules'));
      expect(brief, contains('bundle.dashboard.upcomingActions'));
      expect(page, contains('_offerBundle?.currentVehicleCount ?? 0'));

      expect(brief, isNot(contains('functions.invoke')));
      expect(brief, isNot(contains('Supabase')));
      expect(brief, isNot(contains('http://')));
      expect(brief, isNot(contains('https://')));
    },
  );

  test('vehicle assistant does not invent urgency or market value', () {
    final brief = _read(
      'lib/features/vehicle_care/vehicle_assistant_brief.dart',
    );

    expect(brief, contains('recall.isPlausibleFor(vehicle.model)'));
    expect(brief, contains("'HIGH'"));
    expect(brief, contains("'CRITICAL'"));
    expect(brief, contains('risk.severity.toUpperCase()'));
    expect(brief, contains('isOverdue('));
    expect(brief, contains('isDueSoon('));
    expect(brief, contains('Aucun point prioritaire détecté'));

    for (final forbidden in [
      'prix du marché',
      'valeur de marché',
      'bonne affaire garantie',
      'danger certain',
    ]) {
      expect(brief.toLowerCase(), isNot(contains(forbidden)));
    }
  });
}
