import 'package:autoclair_app/features/insurance_review/insurance_models.dart';
import 'package:flutter_test/flutter_test.dart';

InsuranceSnapshot _snapshot({
  required String id,
  required double premium,
  required double deductible,
  required List<String> guarantees,
}) {
  return InsuranceSnapshot(
    id: id,
    vehicleId: 'v1',
    providerName: 'Assureur',
    annualPremium: premium,
    deductible: deductible,
    snapshotDate: DateTime(2026),
    sourceType: 'MANUAL',
    guarantees: guarantees,
  );
}

void main() {
  test('masks contract number and keeps last four characters', () {
    expect(InsuranceSnapshot.maskContractNumber('ABCD123456'), '••••••3456');
    expect(InsuranceSnapshot.maskContractNumber('12'), '••••');
  });

  test('detects premium, deductible and guarantee changes', () {
    final review = InsuranceReviewResult(
      previous: _snapshot(
        id: 'old',
        premium: 600,
        deductible: 350,
        guarantees: const ['Assistance 0 km', 'Bris de glace'],
      ),
      current: _snapshot(
        id: 'new',
        premium: 660,
        deductible: 500,
        guarantees: const ['Bris de glace', 'Véhicule de remplacement'],
      ),
    );
    expect(review.premiumChange, 60);
    expect(review.premiumChangePercent, closeTo(10, 0.001));
    expect(review.deductibleChange, 150);
    expect(review.removedGuarantees, ['Assistance 0 km']);
    expect(review.addedGuarantees, ['Véhicule de remplacement']);
  });
}
