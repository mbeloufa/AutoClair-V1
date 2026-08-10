import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'V1 commercial UX uses calm reusable loading error and empty states',
    () {
      final statePanel = File(
        'lib/core/widgets/app_state_panel.dart',
      ).readAsStringSync();
      final vehicles = File(
        'lib/features/home/vehicles_page.dart',
      ).readAsStringSync();
      final history = File(
        'lib/features/home/history_page.dart',
      ).readAsStringSync();

      expect(statePanel, contains('class AppStatePanel'));
      expect(statePanel, contains('liveRegion: loading'));
      expect(vehicles, contains("ValueKey('vehicles-loading-state')"));
      expect(vehicles, contains("ValueKey('vehicles-error-state')"));
      expect(vehicles, contains("ValueKey('vehicles-empty-state')"));
      expect(history, contains("ValueKey('history-loading-state')"));
      expect(history, contains("ValueKey('history-error-state')"));
      expect(history, contains("ValueKey('history-empty-state')"));

      expect(
        vehicles,
        isNot(contains("Text(_errorMessage!, textAlign: TextAlign.center)")),
      );
      expect(
        history,
        isNot(contains("Text(_errorMessage!, textAlign: TextAlign.center)")),
      );
    },
  );

  test('V1 route errors stay user-facing and do not expose a raw URI', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();

    expect(router, contains("ValueKey('route-error-state')"));
    expect(router, contains("'Revenir à AutoClair'"));
    expect(router, contains("context.go('/start')"));
    expect(router, isNot(contains(r'${state.uri}')));
  });

  test(
    'V1 first impression explains the product rather than a document tool',
    () {
      final onboarding = File(
        'lib/features/onboarding/onboarding_page.dart',
      ).readAsStringSync();
      final login = File(
        'lib/features/auth/login_page.dart',
      ).readAsStringSync();
      final register = File(
        'lib/features/auth/register_page.dart',
      ).readAsStringSync();

      expect(onboarding, contains("'Votre voiture, plus simple à gérer'"));
      expect(
        onboarding,
        contains("'Comprenez quoi faire, au bon moment, sans jargon.'"),
      );
      expect(onboarding, contains("'Vous gardez le contrôle de vos données.'"));

      expect(
        login,
        contains("'Retrouvez votre véhicule, vos priorités et vos documents.'"),
      );
      expect(
        register,
        contains("'Centralisez votre véhicule, comprenez vos documents"),
      );
      expect(
        register,
        isNot(contains('pour analyser vos documents automobiles')),
      );
    },
  );
}
