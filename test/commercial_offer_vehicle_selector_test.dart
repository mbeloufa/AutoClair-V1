import 'package:autoclair_app/features/commercial_offers/commercial_offer_vehicle_selector.dart';
import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offer vehicle selector works on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 8, 5);
    final vehicles = [
      Vehicle(
        id: 'audi',
        userId: 'user',
        nickname: 'Ma petite voiture avec un nom très long',
        make: 'Audi',
        model: 'A1',
        isPrimary: true,
        createdAt: now,
        updatedAt: now,
      ),
      Vehicle(
        id: 'golf',
        userId: 'user',
        make: 'Volkswagen',
        model: 'Golf',
        isPrimary: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    var selected = 'audi';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: CommercialOfferVehicleSelector(
              vehicles: vehicles,
              selectedVehicleId: selected,
              enabled: true,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('commercial-offer-vehicle-selector')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choisir un véhicule'), findsOneWidget);

    final golfTile = find.byKey(
      const ValueKey('commercial-offer-vehicle-golf'),
    );
    expect(golfTile, findsOneWidget);
    expect(
      find.descendant(
        of: golfTile,
        matching: find.byKey(
          const ValueKey('commercial-offer-vehicle-name-golf'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('commercial-offer-vehicle-details-golf')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(golfTile);
    await tester.pumpAndSettle();
    expect(selected, 'golf');
    expect(tester.takeException(), isNull);
  });

  testWidgets('offer selector shows make and model only below a nickname', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 8, 5);
    final vehicle = Vehicle(
      id: 'audi',
      userId: 'user',
      nickname: 'Ma voiture',
      make: 'Audi',
      model: 'A1',
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: CommercialOfferVehicleSelector(
              vehicles: [vehicle],
              selectedVehicleId: vehicle.id,
              enabled: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('commercial-offer-vehicle-selector')),
    );
    await tester.pumpAndSettle();

    final vehicleTile = find.byKey(
      const ValueKey('commercial-offer-vehicle-audi'),
    );

    expect(vehicleTile, findsOneWidget);
    expect(
      find.descendant(
        of: vehicleTile,
        matching: find.byKey(
          const ValueKey('commercial-offer-vehicle-name-audi'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: vehicleTile,
        matching: find.byKey(
          const ValueKey('commercial-offer-vehicle-details-audi'),
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
