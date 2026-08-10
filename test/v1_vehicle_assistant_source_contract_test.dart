import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('V1 vehicle assistant links move to the visible destination', () {
    final page = _read('lib/features/vehicle_care/vehicle_care_page.dart');
    final brief = _read(
      'lib/features/vehicle_care/vehicle_assistant_brief.dart',
    );
    final card = _read(
      'lib/features/vehicle_care/vehicle_assistant_brief_card.dart',
    );

    expect(page, contains('VehicleAssistantBrief.build('));
    expect(page, contains('VehicleAssistantBriefCard('));
    expect(page, contains('_showCareSection('));
    expect(page, contains('Scrollable.ensureVisible('));
    expect(page, contains('key: _careSectionKey'));
    expect(brief, contains('VehicleAssistantTarget.overview'));
    expect(brief, contains('Rappel constructeur programmé'));
    expect(brief, contains('Entretien à rattraper'));
    expect(brief, contains('Kilométrage à renseigner'));
    expect(brief, contains('.take(3)'));
    expect(card, contains('Votre assistant AutoClair'));
  });

  test('assistant distinguishes recall candidates from confirmed action', () {
    final brief = _read(
      'lib/features/vehicle_care/vehicle_assistant_brief.dart',
    );
    final page = _read('lib/features/vehicle_care/vehicle_care_page.dart');
    final models = _read('lib/features/vehicle_care/vehicle_care_models.dart');

    expect(brief, contains("recall.status.toUpperCase() == 'SCHEDULED'"));
    expect(brief, isNot(contains('recall.isPlausibleFor(vehicle.model)')));
    expect(page, contains('Cela ne confirme pas que ce véhicule est concerné'));
    expect(page, contains('Vérifiez avec le VIN'));
    expect(page, contains('Campagne constructeur à vérifier'));
    expect(models, contains('matchScore >= 0.90'));
  });

  test('assistant reuses data without adding a paid backend call', () {
    final brief = _read(
      'lib/features/vehicle_care/vehicle_assistant_brief.dart',
    );

    expect(brief, contains('bundle.dashboard.recalls'));
    expect(brief, contains('bundle.dashboard.risks'));
    expect(brief, contains('bundle.schedules'));
    expect(brief, contains('bundle.dashboard.upcomingActions'));
    expect(brief, isNot(contains('functions.invoke')));
    expect(brief, isNot(contains('Supabase')));
    expect(brief, isNot(contains('http://')));
    expect(brief, isNot(contains('https://')));
  });
}
