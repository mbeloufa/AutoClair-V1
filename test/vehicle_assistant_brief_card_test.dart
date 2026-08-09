import 'package:autoclair_app/features/vehicle_care/vehicle_assistant_brief.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_assistant_brief_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('assistant brief stays readable on a narrow vehicle screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    VehicleAssistantTarget? selected;

    const brief = VehicleAssistantBrief(
      summary: 'AutoClair a classé les actions à regarder en premier.',
      items: [
        VehicleAssistantItem(
          title: 'Entretien à rattraper',
          message: 'Vidange moteur · à 80 000 km',
          importance: VehicleAssistantImportance.urgent,
          actionLabel: 'Voir l’entretien',
          target: VehicleAssistantTarget.maintenance,
        ),
        VehicleAssistantItem(
          title: 'Kilométrage à renseigner',
          message: 'Ajoutez le kilométrage actuel.',
          importance: VehicleAssistantImportance.useful,
          actionLabel: 'Ajouter les km',
          target: VehicleAssistantTarget.mileage,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: VehicleAssistantBriefCard(
              brief: brief,
              onAction: (target) => selected = target,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Votre assistant AutoClair'), findsOneWidget);
    expect(find.text('Entretien à rattraper'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Voir l’entretien'));
    await tester.pump();

    expect(selected, VehicleAssistantTarget.maintenance);
    expect(tester.takeException(), isNull);
  });
}
