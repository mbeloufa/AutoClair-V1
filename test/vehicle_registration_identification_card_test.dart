import 'package:autoclair_app/features/vehicles/vehicle_identification_result.dart';
import 'package:autoclair_app/features/vehicles/vehicle_registration_identification_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registration card applies VIN and enriched lookup data', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'gg114sk');
    VehicleIdentificationResult? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleRegistrationIdentificationCard(
              controller: controller,
              enabled: true,
              lookup: (_) async => const VehicleIdentificationResult(
                registrationNumber: 'GG-114-SK',
                make: 'SKODA',
                model: 'ENYAQ',
                vehicleYear: 2022,
                fuelType: 'Électrique',
                vin: 'TMBJC7NY5NF039349',
                sourceLabel: 'Source test',
                identity: {'version': '286 ELEMENT 85X', 'trim': '340 RS'},
                technical: {'power_kw': 150, 'fiscal_power': 5},
                aftersales: {'k_type': '142230'},
              ),
              onIdentified: (result) => selected = result,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Identifier mon véhicule'));
    await tester.pumpAndSettle();

    expect(controller.text, 'GG-114-SK');
    expect(selected?.vin, 'TMBJC7NY5NF039349');
    expect(find.text('SKODA ENYAQ'), findsOneWidget);
    expect(find.textContaining('VIN TMBJC7NY5NF039349'), findsOneWidget);
    expect(find.text('Voir les caractéristiques récupérées'), findsOneWidget);
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
