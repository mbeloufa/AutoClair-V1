import 'package:autoclair_app/features/vehicle_care/vehicle_event_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('event form is simple and responsive at 280 pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: VehicleEventFormPage(vehicleId: 'vehicle-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entretien'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('event-subcategory-MAINTENANCE')),
        matching: find.text('Révision et vidange'),
      ),
      findsWidgets,
    );
    expect(find.text('Réalisé'), findsOneWidget);
    expect(find.text('Prévu'), findsOneWidget);
    expect(find.textContaining('Conseillé'), findsNothing);
    expect(find.byKey(const ValueKey('event-reminder-section')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('event-status-planned')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('event-reminder-section')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('event-category-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Choisir une catégorie'), findsOneWidget);
    expect(find.text('Sécurité'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('event-category-SAFETY')));
    await tester.pumpAndSettle();
    expect(find.text('Sécurité'), findsOneWidget);
    expect(find.text('Freinage'), findsWidgets);
    expect(tester.takeException(), isNull);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('event-nearby-garages')),
      280,
      scrollable: scrollable,
    );
    expect(find.byKey(const ValueKey('event-nearby-garages')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('event-document-existing')),
      280,
      scrollable: scrollable,
    );
    expect(find.byKey(const ValueKey('event-document-new')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-document-existing')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
