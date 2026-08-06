import 'package:autoclair_app/features/used_purchase/used_purchase_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a stored used-purchase profile without seller identity', () {
    final profile = UsedPurchaseProfile.fromMap({
      'seller_type': 'AUTOMOTIVE_PROFESSIONAL',
      'make': 'Renault',
      'model': 'Clio',
      'vehicle_year': 2021,
      'mileage': 54000,
      'asking_price_eur': 13900,
      'registration_cost_eur': 320,
      'immediate_repairs_eur': 500,
      'inspection_cost_eur': 120,
      'available_budget_eur': 16000,
      'seller_right_to_sell_verified': true,
      'registration_available': true,
      'vin_matches_registration': true,
      'csa_issued_at': '2026-08-01',
      'csa_clear': true,
      'histovec_reviewed': true,
      'technical_control_date': '2026-07-20',
      'technical_control_status': 'FAVORABLE',
      'mileage_history_coherent': true,
      'maintenance_evidence': true,
      'cold_start_observed': true,
      'warning_lights_clear': true,
      'test_drive_completed': true,
      'braking_steering_healthy': true,
      'leaks_or_smoke_detected': false,
      'body_structure_concern': false,
      'secure_payment_planned': true,
      'deposit_before_checks': false,
    });

    expect(profile.sellerType, PurchaseSellerType.automotiveProfessional);
    expect(profile.vehicleYear, 2021);
    expect(profile.askingPrice, 13900);
    expect(
      profile.technicalControlStatus,
      PurchaseTechnicalControlStatus.favorable,
    );
    expect(profile.toMap(), isNot(contains('seller_name')));
    expect(profile.toMap(), isNot(contains('seller_phone')));
  });

  test('rejects invalid mileage and financial values', () {
    final profile = UsedPurchaseProfile(
      sellerType: PurchaseSellerType.privateIndividual,
      make: 'A',
      model: 'B',
      vehicleYear: 2020,
      mileage: -1,
      askingPrice: 10000,
      registrationCost: 0,
      immediateRepairBudget: 0,
      inspectionCost: 0,
      availableBudget: 12000,
      sellerRightToSellVerified: false,
      registrationAvailable: false,
      vinMatchesRegistration: false,
      csaClear: false,
      histovecReviewed: false,
      technicalControlStatus: PurchaseTechnicalControlStatus.unknown,
      mileageHistoryCoherent: false,
      maintenanceEvidence: false,
      coldStartObserved: false,
      warningLightsClear: false,
      testDriveCompleted: false,
      brakingSteeringHealthy: false,
      leaksOrSmokeDetected: false,
      bodyStructureConcern: false,
      securePaymentPlanned: false,
      depositBeforeChecks: false,
    );

    expect(profile.validate, throwsFormatException);
  });

  test('summary contains the decision but no seller data', () {
    const assessment = UsedPurchaseAssessment(
      score: 82,
      decisionLevel: PurchaseDecisionLevel.caution,
      blockingCount: 0,
      warningCount: 2,
      totalAcquisitionCost: 15500,
      remainingBudget: 1500,
      items: [],
      technicalControlRequired: true,
    );
    final profile = UsedPurchaseProfile.defaults();
    final summary = assessment.buildShareSummary(profile);

    expect(summary, contains('Points à clarifier'));
    expect(summary, contains('15500.00 €'));
    expect(summary.toLowerCase(), isNot(contains('vendeur :')));
    expect(summary.toLowerCase(), isNot(contains('adresse')));
  });
}
