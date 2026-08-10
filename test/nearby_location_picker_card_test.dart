import 'package:autoclair_app/features/home/nearby_location_picker_card.dart';
import 'package:autoclair_app/features/home/nearby_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category location picker stays usable at 280 pixels', (
    tester,
  ) async {
    NearbyLocationService.instance.clearRememberedLocation();
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: NearbyLocationPickerCard(),
          ),
        ),
      ),
    );

    expect(find.text('Où voulez-vous chercher ?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('category-use-current-location')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('category-address-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('category-address-search')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
