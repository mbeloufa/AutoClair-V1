import 'package:autoclair_app/features/documents/document_vehicle_selector.dart';
import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vehicle selector stays readable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 8, 5);
    final vehicles = [
      Vehicle(
        id: 'vehicle-1',
        userId: 'user-1',
        nickname: 'Popomobile avec un nom volontairement très long',
        make: 'Audi',
        model: 'A1 Sportback',
        vehicleYear: 2015,
        isPrimary: true,
        createdAt: now,
        updatedAt: now,
      ),
      Vehicle(
        id: 'vehicle-2',
        userId: 'user-1',
        make: 'Volkswagen',
        model: 'Golf',
        vehicleYear: 2021,
        isPrimary: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    String? selectedId = vehicles.first.id;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Form(
              child: DocumentVehicleSelector(
                vehicles: vehicles,
                selectedVehicleId: selectedId,
                enabled: true,
                onChanged: (value) => selectedId = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Popomobile'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('document-vehicle-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Choisir un véhicule'), findsWidgets);
    expect(find.text('Audi A1 Sportback'), findsOneWidget);
    expect(find.text('Volkswagen Golf'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('document-vehicle-option-vehicle-2')),
    );
    await tester.pumpAndSettle();

    expect(selectedId, 'vehicle-2');
    expect(find.text('Volkswagen Golf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled vehicle selector cannot open the picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 8, 5);
    final vehicle = Vehicle(
      id: 'vehicle-1',
      userId: 'user-1',
      make: 'Audi',
      model: 'A1',
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: DocumentVehicleSelector(
              vehicles: [vehicle],
              selectedVehicleId: vehicle.id,
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('document-vehicle-selector')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
