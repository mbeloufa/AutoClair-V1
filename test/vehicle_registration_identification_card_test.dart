import 'package:autoclair_app/features/vehicles/vehicle_identification_result.dart';
import 'package:autoclair_app/features/vehicles/vehicle_registration_identification_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registration card applies a confirmed lookup suggestion', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'ab123cd');
    VehicleIdentificationResult? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleRegistrationIdentificationCard(
            controller: controller,
            enabled: true,
            lookup: (_) async => const VehicleIdentificationResult(
              registrationNumber: 'AB-123-CD',
              make: 'RENAULT',
              model: 'CLIO',
              vehicleYear: 2020,
              fuelType: 'Essence',
              sourceLabel: 'Source test',
            ),
            onIdentified: (result) => selected = result,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Identifier mon véhicule'));
    await tester.pumpAndSettle();

    expect(controller.text, 'AB-123-CD');
    expect(selected?.make, 'RENAULT');
    expect(find.text('RENAULT CLIO'), findsOneWidget);
    expect(
      find.text('Informations proposées. Vérifiez-les avant d’enregistrer.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'registration card keeps manual entry when lookup is unavailable',
    (tester) async {
      final controller = TextEditingController(text: 'AB-123-CD');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleRegistrationIdentificationCard(
              controller: controller,
              enabled: true,
              lookup: (_) async => throw Exception('offline'),
              onIdentified: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Identifier mon véhicule'));
      await tester.pumpAndSettle();

      expect(find.textContaining('continuer manuellement'), findsOneWidget);
      expect(controller.text, 'AB-123-CD');
    },
  );
}
