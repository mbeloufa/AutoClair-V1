import 'package:autoclair_app/features/home/nearby_location_picker_card.dart';
import 'package:autoclair_app/features/home/nearby_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'location picker exposes only current position or another place',
    (tester) async {
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

      expect(find.text('Zone de recherche'), findsOneWidget);
      expect(find.text('Autour de moi'), findsOneWidget);
      expect(find.text('Choisir un lieu'), findsOneWidget);
      expect(find.text('Ma position'), findsNothing);
      expect(
        find.byKey(const ValueKey('category-address-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('category-location-current')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('category-location-custom')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
