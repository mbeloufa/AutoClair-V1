import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'maintenance V3 keeps a useful fallback and independent technical inspection',
    () {
      final edge = _read(
        'supabase/functions/refresh-vehicle-maintenance-plan/index.ts',
      );
      final migration = _read(
        'supabase/migrations/20260813203000_vehicle_care_plan_v3.sql',
      );
      final service = _read(
        'lib/features/vehicle_care/vehicle_care_service.dart',
      );
      final models = _read(
        'lib/features/vehicle_care/vehicle_care_models.dart',
      );
      final page = _read('lib/features/vehicle_care/vehicle_care_page.dart');
      final config = _read('supabase/config.toml');

      for (final marker in <String>[
        'const RESEARCH_POLICY_VERSION = "maintenance-v3"',
        '.normalize("NFD")',
        '.replace(/[\\u0300-\\u036f]/g, "")',
        'OFFICIAL_GENERAL allowance is only for a general SERVICE',
        'policy_version: RESEARCH_POLICY_VERSION',
        'confidence: confidenceScore(rule.confidence)',
        'max_output_tokens: 30000',
      ]) {
        expect(edge, contains(marker));
      }
      expect(edge, isNot(contains('confidence: rule.confidence,')));
      expect(edge, isNot(contains('confidence: "HIGH",')));

      for (final marker in <String>[
        'create or replace function public.apply_vehicle_maintenance_fallback',
        "'AUTOCLAIR_FALLBACK:' || v_template.code",
        "t.code in ('ENGINE_OIL', 'OIL_FILTER')",
        'coalesce(v.first_registration_date, p.first_registration_date)',
        'select max(e.occurred_at::date)',
        "'TECHNICAL_INSPECTION'",
        "v_last_inspection + interval '2 years'",
        "v_first_registration + interval '4 years'",
        'revoke all on function public.apply_vehicle_maintenance_fallback(uuid)',
        'grant execute on function public.apply_vehicle_maintenance_fallback(uuid)',
      ]) {
        expect(migration, contains(marker));
      }

      expect(service, contains('applyMaintenanceFallback'));
      expect(service, contains("'apply_vehicle_maintenance_fallback'"));
      expect(service, contains('schedule.isAutoClairFallback'));

      expect(models, contains('bool get isAutoClairFallback'));
      expect(models, contains("return 'Repère AutoClair';"));
      expect(
        models,
        contains("sourceQuality?.toUpperCase() == 'OFFICIAL_GENERAL'"),
      );
      expect(models, contains("return 'Constructeur · à confirmer';"));

      for (final marker in <String>[
        'reminders: bundle.dashboard.upcomingActions',
        'À vérifier régulièrement',
        'Pression des pneus',
        'Niveaux essentiels',
        'Éclairage',
        'Contrôle technique',
        'Réglementaire',
        'Repère AutoClair',
        'Contrôlés lors de la révision',
        'Le contrôle visuel du freinage',
        'au sol font partie des points à examiner',
        'applyMaintenanceFallback',
      ]) {
        expect(page, contains(marker));
      }

      expect(config, contains('[functions.refresh-vehicle-maintenance-plan]'));
      expect(config, contains('verify_jwt = true'));
    },
  );
}
