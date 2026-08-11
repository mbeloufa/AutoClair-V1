import 'package:autoclair_app/features/vehicle_care/vehicle_assistant_brief.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_assistant_brief_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const brief = VehicleAssistantBrief(
    summary: 'Une action est à regarder.',
    items: [
      VehicleAssistantItem(
        title: 'Échéance prioritaire',
        message: 'Révision avec vidange · échéance indicative à confirmer',
        importance: VehicleAssistantImportance.urgent,
        actionLabel: 'Voir l’échéance',
        target: VehicleAssistantTarget.maintenance,
      ),
    ],
  );

  testWidgets('assistant brief stays readable on a narrow vehicle screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: VehicleAssistantBriefCard(brief: brief, onAction: (_) {}),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Votre assistant AutoClair'), findsOneWidget);
    expect(find.text('Voir l’échéance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the whole priority card triggers its destination', (
    tester,
  ) async {
    VehicleAssistantTarget? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleAssistantBriefCard(
            brief: brief,
            onAction: (target) => selected = target,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('vehicle-assistant-item-0')));
    await tester.pump();

    expect(selected, VehicleAssistantTarget.maintenance);
  });
}
