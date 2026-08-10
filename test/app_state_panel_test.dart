import 'package:autoclair_app/core/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('commercial state panel stays readable at 280 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: AppStatePanel(
              icon: Icons.cloud_off_outlined,
              title: 'Impossible de charger',
              message: 'Vérifiez votre connexion puis réessayez.',
              tone: AppStateTone.error,
              primaryActionLabel: 'Réessayer',
              onPrimaryAction: () => retried = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-state-panel')), findsOneWidget);
    expect(find.text('Impossible de charger'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });

  testWidgets('loading state exposes a progress indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppStatePanel(
            icon: Icons.description_outlined,
            title: 'Chargement',
            message: 'AutoClair prépare votre espace.',
            loading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
