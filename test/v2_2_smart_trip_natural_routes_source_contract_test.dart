import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Trajet intelligent V2.2 privilegie les trajets naturels', () {
    final backend = File(
      'supabase/functions/analyze-smart-trip/index.ts',
    ).readAsStringSync();

    for (final marker in const <String>[
      'MAX_ROUTE_REQUESTS = 18',
      'SINGLE_FRACTIONS = [0.35, 0.50, 0.68, 0.82]',
      'maxNaturalExtraDistanceKm',
      'Math.max(12, Math.min(60, baseline.distance_km * 0.25))',
      'isNaturalCandidate',
      'isExplorationCandidate',
      'directSavingExists',
      'adaptiveSearchUsed',
      'NATURAL_ROUTE_GUARD_V2_2',
      'via_points: Point[]',
      'candidate.via_points.slice(0, 2)',
      'if (candidate.via_points.length)',
      'considered_routes',
      'max_natural_extra_distance_km',
    ]) {
      expect(backend, contains(marker), reason: 'Marqueur absent : $marker');
    }

    expect(backend, isNot(contains('MAX_ROUTE_REQUESTS = 24')));
    expect(backend, isNot(contains(') <= maxDelay + 10')));
  });

  test('les champs depart et destination peuvent etre vides', () {
    final page = File(
      'lib/features/smart_trip/smart_trip_page.dart',
    ).readAsStringSync();

    expect(page, contains('ValueChanged<SmartTripSuggestion?> onSelected'));
    expect(page, contains('void _clearField()'));
    expect(page, contains("tooltip: 'Vider le champ'"));
    expect(page, contains('ValueListenableBuilder<TextEditingValue>'));
    expect(page, contains('widget.onSelected(null)'));
    expect(page, contains('Icons.close_rounded'));
    expect(page, contains("ValueKey('smart-trip-destination-search')"));
  });
}
