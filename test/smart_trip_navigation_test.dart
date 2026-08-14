import 'package:autoclair_app/features/smart_trip/smart_trip_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apple Plans support', () {
    test('starts at iOS 18.4', () {
      expect(
        supportsAppleSmartTripWaypoints(
          isIOS: true,
          operatingSystemVersion: 'Version 18.3 (Build 22D63)',
        ),
        isFalse,
      );
      expect(
        supportsAppleSmartTripWaypoints(
          isIOS: true,
          operatingSystemVersion: 'Version 18.4 (Build 22E240)',
        ),
        isTrue,
      );
      expect(
        supportsAppleSmartTripWaypoints(
          isIOS: true,
          operatingSystemVersion: 'Version 19.0 (Build 23A1)',
        ),
        isTrue,
      );
    });

    test('falls back to Google when iOS version is unknown', () {
      expect(
        supportsAppleSmartTripWaypoints(
          isIOS: true,
          operatingSystemVersion: 'unknown',
        ),
        isFalse,
      );
      expect(
        supportsAppleSmartTripWaypoints(
          isIOS: false,
          operatingSystemVersion: 'Version 19.0',
        ),
        isFalse,
      );
    });
  });

  test('Google Maps receives AutoClair waypoints in order', () {
    final uri = buildSmartTripGoogleMapsUri(
      origin: '47.000000,4.000000',
      destination: '48.000000,5.000000',
      waypoints: const <String>['47.200000,4.200000', '47.700000,4.700000'],
    );

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['dir_action'], 'navigate');
    expect(
      uri.queryParameters['waypoints'],
      '47.200000,4.200000|47.700000,4.700000',
    );
  });

  test('Google Maps limits waypoints to three', () {
    final uri = buildSmartTripGoogleMapsUri(
      origin: '1,1',
      destination: '9,9',
      waypoints: const <String>['2,2', '3,3', '4,4', '5,5'],
    );

    expect(uri.queryParameters['waypoints'], '2,2|3,3|4,4');
  });

  test('Apple Plans 18.4+ receives repeated waypoints', () {
    final uri = buildSmartTripAppleMapsUri(
      origin: '47.000000,4.000000',
      destination: '48.000000,5.000000',
      waypoints: const <String>['47.200000,4.200000', '47.700000,4.700000'],
      supportsWaypoints: true,
    );

    expect(uri.host, 'maps.apple.com');
    expect(uri.path, '/directions');
    expect(uri.queryParameters['source'], '47.000000,4.000000');
    expect(uri.queryParameters['destination'], '48.000000,5.000000');
    expect(uri.queryParameters['mode'], 'driving');
    expect(uri.queryParameters['start'], '0');
    expect(uri.queryParametersAll['waypoint'], <String>[
      '47.200000,4.200000',
      '47.700000,4.700000',
    ]);
  });

  test('legacy Apple Maps never receives waypoints', () {
    final uri = buildSmartTripAppleMapsUri(
      origin: '47.000000,4.000000',
      destination: '48.000000,5.000000',
      waypoints: const <String>['47.200000,4.200000'],
      supportsWaypoints: false,
    );

    expect(uri.host, 'maps.apple.com');
    expect(uri.path, '/');
    expect(uri.queryParameters['saddr'], '47.000000,4.000000');
    expect(uri.queryParameters['daddr'], '48.000000,5.000000');
    expect(uri.queryParameters.containsKey('waypoint'), isFalse);
  });

  test('Waze only receives the final destination', () {
    final uri = buildSmartTripWazeUri(destination: '48.000000,5.000000');

    expect(uri.host, 'www.waze.com');
    expect(uri.path, '/ul');
    expect(uri.queryParameters['ll'], '48.000000,5.000000');
    expect(uri.queryParameters['navigate'], 'yes');
  });
}
