import 'package:autoclair_app/features/smart_trip/smart_trip_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smart trip V2 parses automatic fuel and optional consumption', () {
    final result = SmartTripResult.fromJson({
      'status': 'SAVING_FOUND',
      'request_id': 'v2-test',
      'method': 'ADAPTIVE_BEAM_V2',
      'origin': {'lat': 48.85, 'lng': 2.35, 'label': 'Paris'},
      'destination': {'lat': 50.63, 'lng': 3.06, 'label': 'Lille'},
      'fuel_price_reference': {
        'price_eur_per_l': 1.812,
        'fuel_type': 'SP95',
        'source': 'OFFICIAL_FRANCE_LOCAL_MEDIAN',
        'sample_count': 24,
      },
      'consumption_reference': {
        'consumption_per_100': 6.5,
        'source': 'ESTIMATED_BY_FUEL',
      },
      'baseline': {
        'id': 'FASTEST_0',
        'label': 'Trajet rapide',
        'strategy': 'FASTEST',
        'complexity_steps': 0,
        'distance_km': 225,
        'duration_minutes': 142,
        'toll_eur': 18.9,
        'energy_quantity': 14.5,
        'energy_cost_eur': 26.27,
        'total_cost_eur': 45.17,
      },
      'recommended': {
        'id': 'SMART_COMBO_0_1_0',
        'label': 'Combinaison optimisée',
        'strategy': 'SMART_COMBO',
        'complexity_steps': 2,
        'distance_km': 229,
        'duration_minutes': 151,
        'toll_eur': 14.4,
        'energy_quantity': 14.8,
        'energy_cost_eur': 26.82,
        'total_cost_eur': 41.22,
      },
      'comparison': {
        'extra_minutes': 9,
        'extra_km': 4,
        'toll_saving_eur': 4.5,
        'energy_cost_delta_eur': 0.55,
        'net_saving_eur': 3.95,
        'percent_saving': 8.7,
      },
      'navigation_waypoints': [
        {'lat': 49.4, 'lng': 2.7},
        {'lat': 50.1, 'lng': 2.9},
      ],
      'tested_routes': 16,
      'pareto_routes': 5,
      'route_requests': 14,
    });

    expect(result.hasSaving, isTrue);
    expect(result.method, 'ADAPTIVE_BEAM_V2');
    expect(result.fuelReference.priceEurPerL, 1.812);
    expect(result.fuelReference.sampleCount, 24);
    expect(result.consumptionReference.isEstimated, isTrue);
    expect(result.recommended.complexitySteps, 2);
    expect(result.testedRoutes, 16);
    expect(result.paretoRoutes, 5);
    expect(result.routeRequests, 14);
  });

  test('suggestion keeps precise selected coordinates', () {
    final suggestion = SmartTripSuggestion.fromJson({
      'id': 'here:test',
      'label': '10 rue Exemple, Paris',
      'subtitle': 'Paris',
      'lat': 48.8566,
      'lng': 2.3522,
    });

    expect(suggestion.label, contains('Paris'));
    expect(suggestion.coordinate, '48.8566,2.3522');
  });
}
