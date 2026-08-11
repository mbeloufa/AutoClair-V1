import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'V1 sources manufacturer maintenance plans without exposing vehicle identity',
    () {
      final migration = _read(
        'supabase/migrations/20260811081500_manufacturer_maintenance_ai_v1.sql',
      );
      final edge = _read(
        'supabase/functions/refresh-vehicle-maintenance-plan/index.ts',
      );
      final service = _read(
        'lib/features/vehicle_care/vehicle_care_service.dart',
      );
      final models = _read(
        'lib/features/vehicle_care/vehicle_care_models.dart',
      );
      final assistant = _read(
        'lib/features/vehicle_care/vehicle_assistant_brief.dart',
      );
      final page = _read('lib/features/vehicle_care/vehicle_care_page.dart');
      final config = _read('supabase/config.toml');

      expect(migration, contains('manufacturer_maintenance_plans'));
      expect(migration, contains('source_key text'));
      expect(migration, contains('source_url text'));
      expect(migration, contains('calculation_basis text'));

      expect(edge, contains('gpt-5.6-terra'));
      expect(edge, contains('"type": "web_search"'));
      expect(edge, contains('allowed_domains'));
      expect(edge, contains('tool_choice: "required"'));
      expect(edge, contains('web_search_call.action.sources'));
      expect(edge, contains('json_schema'));
      expect(edge, contains('OPENAI_API_KEY'));
      expect(edge, contains('HISTORY_CONFIRMED'));
      expect(edge, contains('THEORETICAL_CYCLE'));
      expect(edge, contains("source_type: 'AUTOCLAIR_RULE'"));
      expect(edge, contains('recalculate_vehicle_reminders'));
      expect(edge, isNot(contains('RAPIDAPI_KEY')));
      expect(
        edge,
        contains(
          '.select("id,user_id,make,model,vehicle_year,fuel_type,mileage,first_registration_date")',
        ),
      );
      expect(edge, isNot(contains('registration_number')));

      expect(service, contains('refreshManufacturerMaintenancePlan'));
      expect(service, contains('_effectiveMaintenanceSchedules'));
      expect(models, contains('isManufacturerPlan'));
      expect(models, contains('isGenericPlan'));
      expect(assistant, contains('assistantMaintenanceSchedules'));
      expect(assistant, contains('assistantReminderIsEligible'));
      expect(page, contains('Plan constructeur sourcé'));
      expect(page, contains('Compléter le plan indicatif'));
      expect(config, contains('[functions.refresh-vehicle-maintenance-plan]'));
      expect(config, contains('verify_jwt = true'));
    },
  );
}
