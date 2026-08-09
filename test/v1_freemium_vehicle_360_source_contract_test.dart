import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'V1 gives one real 360 trial and then uses the existing credit ledger',
    () {
      final reportFunction = _read(
        'supabase/functions/generate-vehicle-360-report/index.ts',
      );
      final trialFunction = _read(
        'supabase/functions/claim-vehicle-360-trial/index.ts',
      );
      final service = _read(
        'lib/features/vehicle_insights/vehicle_360_service.dart',
      );
      final page = _read('lib/features/vehicle_insights/vehicle_360_page.dart');

      expect(reportFunction, contains('const billingMode = "credits";'));
      expect(reportFunction, isNot(contains('?? "blocked"')));

      expect(trialFunction, contains('trial:vehicle_360:'));
      expect(trialFunction, contains('vehicle_report_credit_events'));
      expect(trialFunction, contains('event_type: "grant"'));
      expect(trialFunction, contains('external_reference: reference'));
      expect(trialFunction, isNot(contains('stripe')));
      expect(trialFunction, isNot(contains('revenuecat')));

      expect(service, contains("'get_vehicle_report_access'"));
      expect(service, contains("'claim-vehicle-360-trial'"));
      expect(page, contains('Utiliser votre essai gratuit ?'));
      expect(page, contains('Voir les options Premium'));
      expect(page, contains('stores de production'));
    },
  );
}
