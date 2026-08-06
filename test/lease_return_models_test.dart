import 'package:autoclair_app/features/lease_return/lease_return_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LeaseReturnProfile profile({
    Map<LeaseReturnArea, LeaseReturnStatus>? checks,
  }) => LeaseReturnProfile(
    vehicleId: 'vehicle',
    preparedAt: DateTime.now(),
    preparationContext: LeaseReturnContext.beforePreInspection,
    checks:
        checks ??
        {
          for (final area in LeaseReturnArea.values)
            area: LeaseReturnStatus.notChecked,
        },
    vehicleCanMoveSafely: true,
    contractInstructionsAvailable: true,
    allKeysAndAccessoriesAvailable: true,
    warningOrMechanicalConcern: false,
  );

  test('profile requires every structured lease return area', () {
    final checks = {
      for (final area in LeaseReturnArea.values) area: LeaseReturnStatus.ready,
    }..remove(LeaseReturnArea.contractAndInstructions);
    expect(() => profile(checks: checks).validate(), throwsFormatException);
  });

  test(
    'stored map contains no contract identity amount location or free text',
    () {
      final stored = profile().toMap();
      final storedKeys = <String>{};

      void collectKeys(Object? value) {
        if (value is Map) {
          for (final entry in value.entries) {
            storedKeys.add(entry.key.toString().toLowerCase());
            collectKeys(entry.value);
          }
        } else if (value is Iterable) {
          for (final item in value) {
            collectKeys(item);
          }
        }
      }

      collectKeys(stored);
      for (final forbiddenKey in [
        'contract_number',
        'lessor_name',
        'exact_amount',
        'buyout_amount',
        'latitude',
        'longitude',
        'address',
        'photo_url',
        'vin',
        'free_text',
      ]) {
        expect(storedKeys, isNot(contains(forbiddenKey)));
      }
    },
  );

  test('summary states fee contract and acceptance limits', () {
    final assessment = LeaseReturnAssessment(
      level: LeaseReturnLevel.review,
      score: 90,
      completenessPercent: 90,
      urgentCount: 0,
      findings: const [],
    );
    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: profile(),
    );
    expect(summary, contains('ne calcule aucun frais de restitution'));
    expect(summary, contains('n’interprète pas le contrat'));
    expect(summary, contains('ne garantit pas l’acceptation'));
    expect(summary, contains('procès-verbal'));
  });

  test('parses a recent stored lease return preparation', () {
    final snapshot = LeaseReturnSnapshot.fromMap({
      'id': 'preparation',
      'prepared_at': '2026-08-06',
      'preparation_context': 'BEFORE_PRE_INSPECTION',
      'preparation_level': 'ACTION',
      'preparation_score': 72,
      'completeness_percent': 80,
    });
    expect(snapshot.preparationContext, LeaseReturnContext.beforePreInspection);
    expect(snapshot.level, LeaseReturnLevel.action);
    expect(snapshot.score, 72);
  });
}
