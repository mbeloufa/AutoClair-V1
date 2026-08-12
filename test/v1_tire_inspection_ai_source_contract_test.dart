import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'V1 tire photo control is vehicle scoped, visual and safety limited',
    () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      final page = File(
        'lib/features/tire_inspection/tire_inspection_page.dart',
      ).readAsStringSync();
      final service = File(
        'lib/features/tire_inspection/tire_inspection_service.dart',
      ).readAsStringSync();
      final edge = File(
        'supabase/functions/analyze-tire-inspection/index.ts',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/20260812110000_tire_inspection_ai_v1.sql',
      ).readAsStringSync();
      final config = File('supabase/config.toml').readAsStringSync();

      expect(router, contains("path: '/vehicles/:vehicleId/tire-inspection'"));
      expect(router, contains('TireInspectionPage('));
      expect(router, contains("path: '/tire-care'"));
      expect(router, contains("redirect: (context, state) => '/actions'"));

      for (final marker in [
        'FRONT_LEFT_TREAD',
        'FRONT_RIGHT_TREAD',
        'REAR_LEFT_TREAD',
        'REAR_RIGHT_TREAD',
        'FRONT_SIDEWALL',
        'REAR_SIDEWALL',
      ]) {
        expect(edge, contains(marker));
      }
      expect(page, contains('Vos pneus, vérifiés en 6 photos'));
      expect(page, contains('Environ 3 minutes'));
      expect(page, contains('partie du pneu qui touche la route'));
      expect(page, contains('chiffres écrits sur le côté du pneu'));
      expect(page, contains('À ~30 cm'));
      expect(page, contains('À ~20 cm'));
      expect(page, contains('coupez le moteur'));
      expect(page, contains('_AnimatedPhotoGuide'));
      expect(page, contains('AnimationController'));
      expect(page, contains('_CarGuidePainter'));
      expect(page, contains('Voir des prix en ligne'));
      expect(page, isNot(contains('Pneu AVG')));
      expect(page, isNot(contains('Flanc avant')));
      expect(page, isNot(contains('bande de roulement')));

      expect(service, contains("'analyze-tire-inspection'"));
      expect(edge, contains('gpt-5.6-terra'));
      expect(edge, contains('input_image'));
      expect(edge, contains('json_schema'));
      expect(edge, contains('Never estimate tread depth in millimetres'));
      expect(
        edge,
        contains(
          'Never infer SUMMER/WINTER/ALL_SEASON from tread pattern alone',
        ),
      );
      expect(edge, contains('very simple everyday French'));
      expect(edge, contains('Keep each visible finding short'));
      expect(edge, contains('allowed_domains: MERCHANT_DOMAINS'));
      expect(edge, contains('allopneus.com'));
      expect(edge, contains('123pneus.fr'));
      expect(edge, isNot(contains('RAPIDAPI_KEY')));

      expect(migration, contains("'tire-inspections'"));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('create_tire_ai_inspection'));
      expect(migration.trimRight(), endsWith('commit;'));
      expect(config, contains('[functions.analyze-tire-inspection]'));
      expect(config, contains('verify_jwt = true'));
    },
  );
}
