import 'package:autoclair_app/features/home/nearby_location.dart';
import 'package:autoclair_app/features/home/nearby_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(NearbyLocationService.instance.clearRememberedLocation);

  test('geoplatform feature collection exposes sorted unique places', () {
    final results = NearbyLocationService.parseFeatureCollection({
      'features': [
        {
          'geometry': {
            'coordinates': [5.0415, 47.3220],
          },
          'properties': {
            'label': 'Dijon',
            'postcode': '21000',
            'city': 'Dijon',
            'score': 0.82,
          },
        },
        {
          'geometry': {
            'coordinates': [2.3522, 48.8566],
          },
          'properties': {
            'label': 'Paris',
            'postcode': '75000',
            'city': 'Paris',
            'score': 0.95,
          },
        },
        {
          'geometry': {
            'coordinates': [2.3522, 48.8566],
          },
          'properties': {'label': 'Paris en double', 'score': 0.70},
        },
      ],
    });

    expect(results, hasLength(2));
    expect(results.first.label, 'Paris');
    expect(results.first.secondaryLabel, '75000 Paris');
    expect(results.last.label, 'Dijon');
  });

  test('chosen location remains available during the app session', () {
    const location = NearbySearchLocation(
      latitude: 47.3220,
      longitude: 5.0415,
      label: 'Dijon',
    );

    NearbyLocationService.instance.remember(location);

    expect(NearbyLocationService.instance.sessionLocation, same(location));
  });
}
