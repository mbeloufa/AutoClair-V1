import 'package:autoclair_app/features/vehicle_care/vehicle_care_section_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'vehicle care navigation reveals an offscreen opened section',
    (tester) async {
      final pickerKey = GlobalKey();
      final contentKey = GlobalKey();
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 900),
                    KeyedSubtree(
                      key: pickerKey,
                      child: const SizedBox(height: 48),
                    ),
                    const SizedBox(height: 18),
                    KeyedSubtree(
                      key: contentKey,
                      child: const SizedBox(
                        height: 400,
                        child: Text('Entretien ouvert'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(contentKey.currentContext, isNotNull);
      expect(controller.offset, 0);

      final revealed = await ensureVehicleCareSectionVisible(
        contentKey: contentKey,
        fallbackKey: pickerKey,
        duration: Duration.zero,
      );
      await tester.pump();

      expect(revealed, isTrue);
      expect(controller.offset, greaterThan(0));
      expect(find.text('Entretien ouvert'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  testWidgets(
    'vehicle care navigation uses the mounted fallback anchor',
    (tester) async {
      final missingContentKey = GlobalKey();
      final pickerKey = GlobalKey();
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 900),
                    KeyedSubtree(
                      key: pickerKey,
                      child: const SizedBox(
                        height: 48,
                        child: Text('Entretien'),
                      ),
                    ),
                    const SizedBox(height: 400),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(pickerKey.currentContext, isNotNull);

      final revealed = await ensureVehicleCareSectionVisible(
        contentKey: missingContentKey,
        fallbackKey: pickerKey,
        duration: Duration.zero,
      );
      await tester.pump();

      expect(revealed, isTrue);
      expect(controller.offset, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  testWidgets(
    'vehicle care navigation reports a missing anchor',
    (tester) async {
      final missingContentKey = GlobalKey();
      final missingFallbackKey = GlobalKey();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      final revealed = await ensureVehicleCareSectionVisible(
        contentKey: missingContentKey,
        fallbackKey: missingFallbackKey,
        duration: Duration.zero,
      );

      expect(revealed, isFalse);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
