import 'package:autoclair_app/features/legal_support/legal_case_models.dart';
import 'package:autoclair_app/features/legal_support/legal_case_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LegalScopeDecision decide({
    LegalCaseCategory category = LegalCaseCategory.professionalPurchase,
    String counterparty = 'professional',
    String description =
        'Le véhicule a été acheté auprès d’un professionnel puis une panne importante est apparue trois semaines après.',
    bool bodily = false,
    bool court = false,
    bool criminal = false,
    bool crossBorder = false,
  }) => LegalScopeDecision.evaluate(
    category: category,
    counterpartyType: counterparty,
    description: description,
    bodilyInjury: bodily,
    courtStarted: court,
    criminalIssue: criminal,
    crossBorder: crossBorder,
  );

  test('supported professional purchase can be analyzed', () {
    expect(decide().level, LegalScopeLevel.supported);
    expect(decide().canAnalyze, isTrue);
  });

  test('private seller remains dossier-only in V1', () {
    final result = decide(counterparty: 'private_individual');
    expect(result.level, LegalScopeLevel.dossierOnly);
    expect(result.canAnalyze, isFalse);
  });

  test('high-risk situations require professional escalation', () {
    expect(decide(bodily: true).level, LegalScopeLevel.escalationRequired);
    expect(decide(court: true).level, LegalScopeLevel.escalationRequired);
    expect(decide(criminal: true).level, LegalScopeLevel.escalationRequired);
    expect(decide(crossBorder: true).level, LegalScopeLevel.escalationRequired);
  });

  test('short descriptions ask for more information', () {
    final result = decide(description: 'Panne moteur.');
    expect(result.level, LegalScopeLevel.needsInformation);
  });
}
