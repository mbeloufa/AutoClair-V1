import 'package:autoclair_app/features/parking/parking_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses official realtime availability and recommendation', () {
    final offer = ParkingOffer.fromJson({
      'parking_id': 'official:dijon:darcy',
      'name': 'Parking Darcy',
      'address': 'Place Darcy, Dijon',
      'latitude': 47.323,
      'longitude': 5.034,
      'distance_km': 1.2,
      'parking_type': 'underground',
      'access': 'yes',
      'fee': 'paid',
      'park_and_ride': false,
      'covered': true,
      'source_kind': 'official',
      'capacity': 600,
      'available_spaces': 124,
      'availability_status': 'open',
      'realtime': true,
      'confidence': 'official_realtime',
      'availability_updated_at': '2026-08-04T10:00:00Z',
      'availability_source': 'Dijon Métropole / DiviaPark',
      'provider_code': 'dijon_diviapark',
      'external_id': 'darcy',
      'smart_score': 91.4,
      'recommendation_rank': 1,
      'recommendation_reasons': ['124 places libres en temps réel', 'À 1,2 km'],
      'predicted_available_spaces': 98,
      'prediction_samples': 9,
    });

    expect(offer.availabilityLabel, '124 places libres');
    expect(offer.confidenceLabel, 'Temps réel officiel');
    expect(offer.isRecommended, isTrue);
    expect(offer.hasPrediction, isTrue);
    expect(offer.predictedAvailableSpaces, 98);
    expect(offer.occupancyRate, closeTo(0.7933, 0.001));
  });

  test('does not present stale data as current availability', () {
    final offer = ParkingOffer.fromJson({
      'parking_id': 'official:nantes:5',
      'name': 'Parking Aristide Briand',
      'address': 'Nantes',
      'latitude': 47.217,
      'longitude': -1.56,
      'distance_km': 2.1,
      'parking_type': 'underground',
      'access': 'yes',
      'fee': 'paid',
      'park_and_ride': false,
      'covered': true,
      'source_kind': 'official',
      'capacity': 303,
      'available_spaces': 179,
      'availability_status': 'open',
      'realtime': true,
      'confidence': 'official_stale',
      'smart_score': 48,
      'recommendation_rank': 3,
      'recommendation_reasons': [],
    });

    expect(offer.availabilityLabel, '179 places — donnée ancienne');
    expect(offer.availabilityIsFresh, isFalse);
    expect(offer.availabilityIsStale, isTrue);
  });

  test('keeps cartographic parking explicit when realtime is unavailable', () {
    final offer = ParkingOffer.fromJson({
      'parking_id': 'way-123',
      'name': 'Parking',
      'address': '',
      'latitude': 47.32,
      'longitude': 5.04,
      'distance_km': 0.8,
      'parking_type': 'surface',
      'access': 'unknown',
      'fee': 'unknown',
      'park_and_ride': false,
      'covered': false,
      'source_kind': 'facility',
      'availability_status': 'unknown',
      'realtime': false,
      'confidence': 'osm',
      'smart_score': 32,
      'recommendation_rank': 4,
      'recommendation_reasons': ['À 800 m'],
    });

    expect(offer.availabilityLabel, 'Disponibilité inconnue');
    expect(offer.confidenceLabel, 'Donnée cartographique');
    expect(offer.hasKnownAvailability, isFalse);
  });
}
