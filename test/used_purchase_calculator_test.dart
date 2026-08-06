import 'package:autoclair_app/features/used_purchase/used_purchase_calculator.dart';
import 'package:autoclair_app/features/used_purchase/used_purchase_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a ready purchase file and calculates total cost', () {
    final assessment = UsedPurchaseCalculator.assess(
      profile: _profile(
        vehicleYear: 2024,
        csaIssuedAt: DateTime(2026, 8, 1),
        askingPrice: 15000,
        registrationCost: 450,
        immediateRepairBudget: 400,
        inspectionCost: 150,
        availableBudget: 18000,
      ),
      now: DateTime(2026, 8, 5),
    );

    expect(assessment.decisionLevel, PurchaseDecisionLevel.ready);
    expect(assessment.blockingCount, 0);
    expect(assessment.totalAcquisitionCost, 16000);
    expect(assessment.remainingBudget, 2000);
    expect(assessment.csaExpiresAt, DateTime(2026, 8, 15));
    expect(assessment.technicalControlRequired, isFalse);
  });

  test('blocks an expired or opposed administrative certificate', () {
    final assessment = UsedPurchaseCalculator.assess(
      profile: _profile(csaIssuedAt: DateTime(2026, 7, 1), csaClear: false),
      now: DateTime(2026, 8, 5),
    );

    expect(assessment.decisionLevel, PurchaseDecisionLevel.stop);
    expect(
      assessment.items.where((item) => item.code == 'CSA').single.level,
      PurchaseCheckLevel.blocking,
    );
  });

  test('requires a valid technical control for an older vehicle', () {
    final assessment = UsedPurchaseCalculator.assess(
      profile: _profile(
        vehicleYear: 2018,
        csaIssuedAt: DateTime(2026, 8, 1),
        technicalControlStatus: PurchaseTechnicalControlStatus.unknown,
      ),
      now: DateTime(2026, 8, 5),
    );

    expect(assessment.technicalControlRequired, isTrue);
    expect(
      assessment.items
          .where((item) => item.code == 'TECHNICAL_CONTROL')
          .single
          .level,
      PurchaseCheckLevel.blocking,
    );
  });

  test('uses calendar months for a control issued on month end', () {
    final assessment = UsedPurchaseCalculator.assess(
      profile: _profile(
        vehicleYear: 2018,
        csaIssuedAt: DateTime(2026, 7, 18),
        technicalControlDate: DateTime(2026, 1, 31),
        technicalControlStatus: PurchaseTechnicalControlStatus.favorable,
      ),
      now: DateTime(2026, 7, 30),
    );

    expect(assessment.technicalControlExpiresAt, DateTime(2026, 7, 31));
    expect(
      assessment.items
          .where((item) => item.code == 'TECHNICAL_CONTROL')
          .single
          .level,
      PurchaseCheckLevel.ready,
    );
  });

  test('blocks unsafe structure and an over-budget purchase', () {
    final assessment = UsedPurchaseCalculator.assess(
      profile: _profile(
        vehicleYear: 2024,
        csaIssuedAt: DateTime(2026, 8, 1),
        askingPrice: 20000,
        availableBudget: 18000,
        bodyStructureConcern: true,
      ),
      now: DateTime(2026, 8, 5),
    );

    expect(assessment.decisionLevel, PurchaseDecisionLevel.stop);
    expect(assessment.remainingBudget, -2000);
    expect(
      assessment.items.where((item) => item.code == 'STRUCTURE').single.level,
      PurchaseCheckLevel.blocking,
    );
    expect(
      assessment.items.where((item) => item.code == 'BUDGET').single.level,
      PurchaseCheckLevel.blocking,
    );
  });
}

UsedPurchaseProfile _profile({
  int? vehicleYear = 2024,
  DateTime? csaIssuedAt,
  bool csaClear = true,
  DateTime? technicalControlDate,
  PurchaseTechnicalControlStatus technicalControlStatus =
      PurchaseTechnicalControlStatus.notRequired,
  double askingPrice = 10000,
  double registrationCost = 0,
  double immediateRepairBudget = 0,
  double inspectionCost = 0,
  double availableBudget = 15000,
  bool bodyStructureConcern = false,
}) {
  return UsedPurchaseProfile(
    sellerType: PurchaseSellerType.privateIndividual,
    make: 'Volkswagen',
    model: 'Golf',
    vehicleYear: vehicleYear,
    mileage: 90000,
    askingPrice: askingPrice,
    registrationCost: registrationCost,
    immediateRepairBudget: immediateRepairBudget,
    inspectionCost: inspectionCost,
    availableBudget: availableBudget,
    sellerRightToSellVerified: true,
    registrationAvailable: true,
    vinMatchesRegistration: true,
    csaIssuedAt: csaIssuedAt,
    csaClear: csaClear,
    histovecReviewed: true,
    technicalControlDate: technicalControlDate,
    technicalControlStatus: technicalControlStatus,
    mileageHistoryCoherent: true,
    maintenanceEvidence: true,
    coldStartObserved: true,
    warningLightsClear: true,
    testDriveCompleted: true,
    brakingSteeringHealthy: true,
    leaksOrSmokeDetected: false,
    bodyStructureConcern: bodyStructureConcern,
    securePaymentPlanned: true,
    depositBeforeChecks: false,
  );
}
