import 'package:autoclair_app/core/widgets/comparison_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepte uniquement des coordonnées géographiques valides', () {
    const valid = ComparisonMapMarkerData(
      id: 'station-1',
      latitude: 47.322,
      longitude: 5.0415,
      label: '1,75 €',
      icon: Icons.local_gas_station,
      color: Colors.blue,
    );
    const invalid = ComparisonMapMarkerData(
      id: 'station-2',
      latitude: 190,
      longitude: 5.0415,
      label: '150 kW',
      icon: Icons.ev_station,
      color: Colors.green,
    );

    expect(valid.hasFiniteCoordinates, isTrue);
    expect(invalid.hasFiniteCoordinates, isFalse);
  });
}
