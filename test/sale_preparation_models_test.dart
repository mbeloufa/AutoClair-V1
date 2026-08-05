import 'package:autoclair_app/features/sale_preparation/sale_preparation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a stored sale preparation profile', () {
    final profile = SalePreparationProfile.fromMap({
      'buyer_type': 'AUTOMOTIVE_PROFESSIONAL',
      'asking_price_eur': 18000,
      'minimum_price_eur': 17000,
      'preparation_cost_eur': 350,
      'owns_vehicle': true,
      'registration_available': true,
      'coholders_ready': true,
      'technical_control_date': '2026-07-01',
      'technical_control_status': 'FAVORABLE',
      'csa_issued_at': '2026-08-01',
      'histovec_shared': true,
      'invoices_available': true,
      'spare_key_count': 2,
      'cession_method': 'SIMPLIMMAT',
    });

    expect(profile.buyerType, SaleBuyerType.automotiveProfessional);
    expect(profile.askingPrice, 18000);
    expect(profile.technicalControlDate, DateTime(2026, 7, 1));
    expect(profile.cessionMethod, SaleCessionMethod.simplimmat);
  });

  test('rejects a minimum price above the asking price', () {
    final profile = SalePreparationProfile(
      buyerType: SaleBuyerType.privateIndividual,
      askingPrice: 10000,
      minimumPrice: 11000,
      preparationCost: 0,
      ownsVehicle: true,
      registrationAvailable: true,
      coHoldersReady: true,
      technicalControlStatus: SaleTechnicalControlStatus.unknown,
      histovecShared: false,
      invoicesAvailable: false,
      spareKeyCount: 1,
      cessionMethod: SaleCessionMethod.undecided,
    );

    expect(profile.validate, throwsFormatException);
  });

  test('normalizes a stored snapshot', () {
    final snapshot = SalePreparationSnapshot.fromMap({
      'id': 'snapshot-1',
      'readiness_score': 88,
      'blocking_count': 0,
      'warning_count': 1,
      'expected_net_at_asking_eur': 14500,
      'created_at': '2026-08-05T20:00:00Z',
    });

    expect(snapshot.score, 88);
    expect(snapshot.expectedNetAtAsking, 14500);
  });
}
