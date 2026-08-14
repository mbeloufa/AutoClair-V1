import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smart trip V2 is adaptive, autocomplete and price automatic', () {
    final edge = File(
      'supabase/functions/analyze-smart-trip/index.ts',
    ).readAsStringSync();
    final page = File(
      'lib/features/smart_trip/smart_trip_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/smart_trip/smart_trip_service.dart',
    ).readAsStringSync();

    for (final marker in [
      'ADAPTIVE_BEAM_V2',
      'PARETO_MULTI_PASS_NO_TOLL_CORRIDOR',
      'SINGLE_FRACTIONS',
      'WINDOW_FRACTIONS',
      'SMART_SINGLE',
      'SMART_WINDOW',
      'SMART_COMBO',
      'pareto(',
      'nearBest',
      'search-fuel-stations',
      'OFFICIAL_FRANCE_LOCAL_MEDIAN',
      'OFFICIAL_FRANCE_SAMPLE_MEDIAN',
      'HERE_AUTOSUGGEST_URL',
      'mode === "autocomplete"',
      '!passThrough=true',
    ]) {
      expect(edge, contains(marker), reason: marker);
    }

    for (final marker in [
      'Choisir point départ',
      'Consommation moyenne (optionnel)',
      'smart-trip-delay-slider',
      'Slider(',
      'Prix du carburant récupéré automatiquement',
      '_PlaceSearchField',
      'Duration(milliseconds: 350)',
      'Sélectionnez une destination dans les résultats proposés.',
      'Optimiser mon trajet',
    ]) {
      expect(page, contains(marker), reason: marker);
    }

    expect(page, isNot(contains("smart_trip_price_")));
    expect(page, isNot(contains("labelText: 'Prix")));
    expect(page, isNot(contains('ChoiceChip(')));
    expect(service, contains("'mode': 'autocomplete'"));
    expect(service, contains('double? consumptionPer100'));
    expect(service, contains("'consumption_per_100': ?consumptionPer100"));
    expect(service, isNot(contains('if (consumptionPer100 != null)')));
    expect(service, isNot(contains('energyPrice')));
  });
}
