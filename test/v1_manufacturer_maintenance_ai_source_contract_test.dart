import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'V2 maintenance is history-first, manufacturer-sourced and reports refresh failures',
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

      for (final marker in <String>[
        'gpt-5.6-terra',
        'type: "web_search"',
        'allowed_domains',
        'tool_choice: "required"',
        'web_search_call.action.sources',
        'type: "json_schema"',
        'OPENAI_API_KEY',
        'buildMaintenanceHistory',
        'maintenance_history',
        'history_fingerprint',
        'researchSignature',
        'HISTORY_CONFIRMED',
        'THEORETICAL_CYCLE',
        'SEASONAL:CLIMATE',
        'Routine inspection-only checks',
        'max_output_tokens: 30000',
        'OPENAI_INCOMPLETE',
        'AI_RESPONSE_INCOMPLETE',
        'AI_TEMPORARILY_UNAVAILABLE',
        'classifyMaintenanceFailure',
      ]) {
        expect(edge, contains(marker));
      }
      expect(edge, isNot(contains('max_output_tokens: 6500')));
      expect(edge, isNot(contains('registration_number')));
      expect(edge, contains('VIN, registration plate'));

      for (final marker in <String>[
        'VehicleMaintenanceRefreshResult',
        'forceRefresh',
        'errorCode',
        'userMessage',
        '_maintenanceFunctionErrorCode',
        'FUNCTION_UNREACHABLE',
        '.details',
      ]) {
        expect(service, contains(marker));
      }
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
      expect(page, contains('Rechercher mon plan d’entretien'));
      expect(page, contains('if (!result.success)'));
      expect(page, contains('_message(result.userMessage)'));
      expect(page, contains('forceRefresh: alreadyHasManufacturerPlan'));
      expect(page, contains('Contrôlés lors de la révision'));
      expect(page, contains('Pourquoi c’est utile ?'));
      expect(config, contains('[functions.refresh-vehicle-maintenance-plan]'));
      expect(config, contains('verify_jwt = true'));
    },
  );
}
