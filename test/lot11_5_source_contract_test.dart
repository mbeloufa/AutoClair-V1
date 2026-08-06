import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 11.5 exposes a prominent action center from home', () {
    final router = _read('lib/core/router/app_router.dart');
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains("import '../../features/home/action_center_page.dart';"),
    );
    expect(router, contains("path: '/actions'"));
    expect(router, contains('const ActionCenterPage()'));

    expect(home, contains("ValueKey('home-action-center-banner')"));
    expect(home, contains("'Tous les outils AutoClair'"));
    expect(home, contains("context.push<void>('/actions')"));
    expect(home, contains("ValueKey('home-all-tools-tile')"));
    expect(home, contains("title: 'Tous les outils'"));
    expect(home, contains("'Ouvrir les 15 outils'"));
  });

  test('lot 11.5 gives every Lot 4 to Lot 14 module a direct button', () {
    final center = _read('lib/features/home/action_center_page.dart');

    final expectedActions = <String, String>{
      'Gérer une panne': '/breakdown-assistant',
      'Gérer un accident': '/accident-assistant',
      'Réagir à un vol': '/theft-assistant',
      'Sécuriser mon achat': '/used-purchase',
      'Préparer ma vente': '/sale-preparation',
      'Planifier mon entretien': '/maintenance-planner',
      'Anticiper les risques': '/risk-forecast',
      'Inspecter mon véhicule': '/vehicle-inspection',
      'Améliorer ma conduite': '/eco-driving',
      'Mon budget automobile': '/budget',
      'Optimiser mon plein': '/fuel-optimizer',
      'Optimiser ma recharge': '/charging-optimizer',
      'Comparer mes devis': '/quote-comparison',
      'Vérifier ma conformité': '/compliance',
      'Réviser mon assurance': '/insurance-review',
    };

    for (final entry in expectedActions.entries) {
      expect(center, contains("title: '${entry.key}'"));
      expect(center, contains("route: '${entry.value}'"));
    }

    expect(RegExp(r"route: '/[^']+'").allMatches(center).length, 15);
    expect(center, contains('context.push<void>(tool.route)'));
  });

  test('lot 11.5 groups tools by moments of vehicle life', () {
    final center = _read('lib/features/home/action_center_page.dart');

    for (final section in [
      'Urgence et imprévus',
      'Acheter et vendre',
      'Entretenir et conduire',
      'Budget et économies',
    ]) {
      expect(center, contains("title: '$section'"));
    }

    expect(center, contains("ValueKey('action-center-scroll')"));
    expect(center, contains(r"ValueKey('action-section-${section.keyName}')"));
    expect(center, contains(r"ValueKey('action-tool-${tool.route}')"));
    expect(center, contains('constraints.maxWidth >= 600'));
  });

  test('lot 11.5 changes navigation only and adds no backend dependency', () {
    final center = _read('lib/features/home/action_center_page.dart');
    final home = _read('lib/features/home/home_page.dart');
    final router = _read('lib/core/router/app_router.dart');

    for (final source in [center, home, router]) {
      expect(source, isNot(contains('functions.invoke')));
      expect(source, isNot(contains('Supabase.instance.client.from')));
      expect(source, isNot(contains('recordCost(')));
      expect(source, isNot(contains('recordOpportunity(')));
      expect(source, isNot(contains('ScaffoldMessenger.of(this.context)')));
      expect(RegExp(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(source), isFalse);
    }
  });
}

String _read(String relativePath) {
  return File(relativePath).readAsStringSync();
}
