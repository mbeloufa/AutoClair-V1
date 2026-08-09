import 'package:autoclair_app/features/vehicle_care/vehicle_smart_reminder_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('essential reminder card stays readable on a narrow screen', (
    tester,
  ) async {
    bool? changed;

    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleSmartReminderCard(
              enabled: false,
              busy: false,
              availableCount: 2,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Rappels essentiels'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vehicle-smart-reminder-switch')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(changed, isTrue);
  });

  testWidgets('enabled card explains when no dated reminder is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleSmartReminderCard(
            enabled: true,
            busy: false,
            availableCount: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.textContaining('dès qu’une date utile sera connue'),
      findsOneWidget,
    );
  });
}
