import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter commercial offers service uses the V4 bridge only', () {
    final source = File(
      'lib/features/commercial_offers/commercial_offers_service.dart',
    ).readAsStringSync();

    expect(source, contains("'get_vehicle_commercial_offers_v4'"));
    expect(source, contains("'set_vehicle_commercial_offer_preference_v4'"));
    expect(source, contains("'reset_vehicle_offer_dismissals_v4'"));
    expect(
      RegExp(r"'get_vehicle_commercial_offers'\s*,").hasMatch(source),
      isFalse,
    );
  });

  test('V4 bridge returns the complete bundle expected by Flutter', () {
    final migration = File(
      'supabase/migrations/'
      '20260806233000_commercial_offers_v4_flutter_bridge.sql',
    ).readAsStringSync();

    for (final field in <String>[
      "'vehicle_id'",
      "'vehicle_name'",
      "'generated_at'",
      "'active_source_count'",
      "'active_offer_count'",
      "'last_successful_sync_at'",
      "'offers'",
      "'compatibility'",
      "'relevance_score'",
      "'relevant_now'",
      "'is_saved'",
      "'why'",
      "'official_url'",
      "'match_level'",
      "'match_score'",
      "'is_brand_fallback'",
    ]) {
      expect(migration, contains(field), reason: 'Missing field $field');
    }

    expect(migration, contains('public.match_commercial_offers_v4('));
    expect(migration, contains("m.match_level in ('CONFIRMED','LIKELY')"));
    expect(migration, contains("coalesce(pref.status, 'NONE') <> 'DISMISSED'"));
    expect(migration, contains('limit v_limit'));
  });

  test('V4 preferences remain private and reversible', () {
    final migration = File(
      'supabase/migrations/'
      '20260806233000_commercial_offers_v4_flutter_bridge.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        'alter table public.commercial_offer_v4_preferences enable row level security',
      ),
    );
    expect(migration, contains('user_id = auth.uid()'));
    expect(migration, contains("v_status not in ('NONE','SAVED','DISMISSED')"));
    expect(migration, contains("p.status = 'DISMISSED'"));
    expect(migration.trimRight().endsWith('commit;'), isTrue);
  });
}
