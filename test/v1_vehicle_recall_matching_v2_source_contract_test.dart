import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'V1 centralizes recall matching in Supabase and stores first registration date',
    () {
      final home = File('lib/features/home/home_page.dart').readAsStringSync();
      final assistant = File(
        'lib/features/vehicle_care/vehicle_assistant_brief.dart',
      ).readAsStringSync();
      final care = File(
        'lib/features/vehicle_care/vehicle_care_page.dart',
      ).readAsStringSync();
      final vehicle = File(
        'lib/features/vehicles/vehicle.dart',
      ).readAsStringSync();
      final form = File(
        'lib/features/vehicles/vehicle_form_page.dart',
      ).readAsStringSync();
      final service = File(
        'lib/features/vehicles/vehicle_service.dart',
      ).readAsStringSync();
      final edge = File(
        'supabase/functions/sync-vehicle-recalls/index.ts',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/20260810210000_vehicle_recall_matching_v2.sql',
      ).readAsStringSync();

      for (final source in <String>[home, assistant, care]) {
        expect(source, isNot(contains('recall.isPlausibleFor(vehicle.model)')));
      }
      expect(home, contains("recall.status.toUpperCase() == 'SCHEDULED'"));
      expect(assistant, contains("recall.status.toUpperCase() == 'SCHEDULED'"));
      expect(
        RegExp(r'\(recall\)\s*=>\s*recall\.requiresAttention').hasMatch(care),
        isTrue,
      );

      expect(vehicle, contains('final DateTime? firstRegistrationDate;'));
      expect(form, contains("labelText: 'Mise en circulation'"));
      expect(form, contains('result.firstRegistrationDate'));
      expect(form, contains("tooltip: 'Effacer la date'"));
      expect(service, contains("'set_vehicle_first_registration_date'"));
      expect(service, contains("'match_vehicle_recalls'"));

      expect(edge, contains('"identification_produits"'));
      expect(edge, contains('"informations_complementaires"'));
      expect(edge, contains('"informations_complementaires_publiques"'));
      expect(edge, contains('identification_products:'));
      expect(edge, contains('additional_public_information:'));

      expect(migration, contains('first_registration_date date'));
      expect(migration, contains('recall_match_score_v2'));
      expect(migration, contains('recall_context_contains_vin'));
      expect(migration, contains('sync_vehicle_recall_matches_v2'));
      expect(
        migration,
        contains(
          'select public.match_all_vehicle_recalls() as recall_matches_recalculated;',
        ),
      );
      expect(
        RegExp(
          r'perform\s+public\.recalculate_vehicle_reminders',
        ).allMatches(migration).length,
        1,
        reason:
            'Le recalcul global ne doit pas exiger une session utilisateur.',
      );
      expect(migration.trimRight().endsWith('commit;'), isTrue);
    },
  );
}
