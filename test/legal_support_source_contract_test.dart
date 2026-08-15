import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('Litiges & démarches V1 is exposed with careful wording', () {
    final router = read('lib/core/router/app_router.dart');
    final home = read('lib/features/home/home_page.dart');
    final page = read('lib/features/legal_support/legal_support_page.dart');

    expect(router, contains("path: '/legal-support'"));
    expect(home, contains("ValueKey('home-legal-support-card')"));
    expect(home, contains('Litiges & démarches'));
    expect(page, contains('Assistant IA AutoClair'));
    expect(
      page,
      contains('ne remplace pas l’avis d’un professionnel du droit'),
    );
    expect(page, isNot(contains('Avocat IA')));
    expect(page, isNot(contains('Conseiller juridique')));
    expect(page, contains("ValueKey('legal-support-delete-case')"));
  });

  test('legal analysis is constrained to official sources', () {
    final edge = read('supabase/functions/analyze-legal-case/index.ts');

    expect(edge, contains('legifrance.gouv.fr'));
    expect(edge, contains('service-public.fr'));
    expect(edge, contains('economie.gouv.fr'));
    expect(edge, contains('allowed_domains'));
    expect(edge, contains('web_search'));
    expect(edge, contains('Aucune jurisprudence'));
    expect(edge, contains('source_verification_failed'));
    expect(edge, contains('store: false'));
  });

  test('legal tables are RLS-protected', () {
    final migration = read(
      'supabase/migrations/20260815173000_legal_disputes_v1.sql',
    );

    for (final table in [
      'legal_cases',
      'legal_case_facts',
      'legal_case_documents',
      'legal_assessments',
    ]) {
      expect(
        migration,
        contains('alter table public.$table enable row level security'),
      );
    }
    expect(migration, contains('to authenticated'));
    expect(migration, contains('(select auth.uid()) = user_id'));
  });
}
