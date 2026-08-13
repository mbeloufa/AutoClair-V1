import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'V2 maintenance is history-first, manufacturer-sourced and privacy-minimized',
    () {
      final edge = File(
        'supabase/functions/refresh-vehicle-maintenance-plan/index.ts',
      ).readAsStringSync();
      final config = File('supabase/config.toml').readAsStringSync();
      final service = File(
        'lib/features/vehicle_care/vehicle_care_service.dart',
      ).readAsStringSync();
      final models = File(
        'lib/features/vehicle_care/vehicle_care_models.dart',
      ).readAsStringSync();
      final assistant = File(
        'lib/features/vehicle_care/vehicle_assistant_brief.dart',
      ).readAsStringSync();
      final page = File(
        'lib/features/vehicle_care/vehicle_care_page.dart',
      ).readAsStringSync();

      expect(edge, contains('gpt-5.6-terra'));
      expect(edge, contains('type: "web_search"'));
      expect(edge, contains('allowed_domains'));
      expect(edge, contains('tool_choice: "required"'));
      expect(edge, contains('web_search_call.action.sources'));
      expect(edge, contains('type: "json_schema"'));
      expect(edge, contains('OPENAI_API_KEY'));
      expect(edge, contains('buildMaintenanceHistory'));
      expect(edge, contains('maintenance_history'));
      expect(edge, contains('history_fingerprint'));
      expect(edge, contains('researchSignature'));
      expect(edge, contains('HISTORY_CONFIRMED'));
      expect(edge, contains('THEORETICAL_CYCLE'));
      expect(edge, contains('benefit'));
      expect(edge, contains('Routine inspection-only checks'));
      expect(edge, contains('isBundledRoutineComponent'));
      expect(edge, contains('SEASONAL:CLIMATE'));
      expect(edge, contains('AUTOCLAIR_RULE'));
      expect(edge, contains('pas recharge systématique'));
      expect(edge, isNot(contains('registration_number')));
      expect(edge, contains('VIN, registration plate'));

      expect(service, contains('VehicleMaintenanceRefreshResult'));
      expect(service, contains('forceRefresh'));
      expect(
        service,
        contains(".where((schedule) => !schedule.isGenericPlan)"),
      );
      expect(models, contains('isSeasonalAdvice'));
      expect(models, contains('benefitText'));
      expect(models, contains('planBadgeLabel'));
      expect(
        assistant,
        contains('!schedule.isGenericPlan && !schedule.isSeasonalAdvice'),
      );

      expect(page, contains('Votre entretien, adapté à votre voiture'));
      expect(page, contains('Actualiser mon plan d’entretien'));
      expect(page, contains('Rechercher mon plan d’entretien'));
      expect(page, contains('Contrôlés lors de la révision'));
      expect(page, contains('Conseil saisonnier'));
      expect(page, contains('Pourquoi c’est utile ?'));
      expect(page, isNot(contains('Compléter le plan indicatif')));
      expect(page, isNot(contains('Créer le plan d’entretien ?')));

      expect(config, contains('[functions.refresh-vehicle-maintenance-plan]'));
      expect(config, contains('verify_jwt = true'));
    },
  );
}
