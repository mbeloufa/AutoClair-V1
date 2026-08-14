import 'package:autoclair_app/features/smart_trip/smart_trip_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smart trip parses a saving', () {
    final r = SmartTripResult.fromJson({
      'status': 'SAVING_FOUND',
      'request_id': 'x',
      'origin': {'lat': 48.85, 'lng': 2.35, 'label': 'Paris'},
      'destination': {'lat': 43.30, 'lng': 5.37, 'label': 'Marseille'},
      'baseline': {
        'id': 'FASTEST_0',
        'label': 'Rapide',
        'distance_km': 775,
        'duration_minutes': 450,
        'toll_eur': 45,
        'energy_quantity': 48.5,
        'energy_cost_eur': 82,
        'total_cost_eur': 127,
      },
      'recommended': {
        'id': 'HYBRID_85_0',
        'label': 'Hybride',
        'distance_km': 781,
        'duration_minutes': 461,
        'toll_eur': 35,
        'energy_quantity': 47.9,
        'energy_cost_eur': 82.8,
        'total_cost_eur': 117.8,
      },
      'comparison': {
        'extra_minutes': 11,
        'extra_km': 6,
        'toll_saving_eur': 10,
        'energy_cost_delta_eur': 0.8,
        'net_saving_eur': 9.2,
        'percent_saving': 7.2,
      },
      'navigation_waypoints': [
        {'lat': 47.0, 'lng': 3.0},
        {'lat': 45.0, 'lng': 4.0},
      ],
      'tested_routes': 6,
    });
    expect(r.hasSaving, isTrue);
    expect(r.comparison.netSavingEur, 9.2);
    expect(r.navigationWaypoints, hasLength(2));
    expect(r.recommended.energyQuantity, 47.9);
  });
  test('baseline best does not claim saving', () {
    final r = SmartTripResult.fromJson({
      'status': 'BASELINE_BEST',
      'origin': {},
      'destination': {},
      'baseline': {},
      'recommended': {},
      'comparison': {},
    });
    expect(r.hasSaving, isFalse);
  });
}
