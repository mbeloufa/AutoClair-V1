import 'package:autoclair_app/features/home/nearby_location_service.dart';
import 'package:autoclair_app/features/home/nearby_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('nearby location search remains usable at 280 pixels', (
    tester,
  ) async {
    NearbyLocationService.instance.clearRememberedLocation();
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: NearbyPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('nearby-location-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('nearby-use-current-location')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nearby-address-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
