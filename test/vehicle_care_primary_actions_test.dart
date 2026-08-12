import 'package:autoclair_app/features/vehicle_care/vehicle_care_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vehicle care actions have labels and no overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: VehicleCarePrimaryActions(
              disabled: false,
              onEvent: () {},
              onMileage: () {},
              onOffers: () {},
              onDocument: () {},
              onTireInspection: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajouter au carnet'), findsOneWidget);
    expect(find.text('Mettre à jour les km'), findsOneWidget);
    expect(find.text('Voir les promos'), findsOneWidget);
    expect(find.text('Ajouter un document'), findsOneWidget);
    expect(find.text('Contrôle pneus IA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
