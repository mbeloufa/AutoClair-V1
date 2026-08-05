import 'package:autoclair_app/features/sale_preparation/sale_preparation_calculator.dart';
import 'package:autoclair_app/features/sale_preparation/sale_preparation_models.dart';
import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a ready private-sale file and calculates net proceeds', () {
    final assessment = SalePreparationCalculator.assess(
      vehicle: _vehicle(year: 2018),
      profile: _profile(
        askingPrice: 12000,
        minimumPrice: 11000,
        preparationCost: 450,
        technicalControlDate: DateTime(2026, 3, 1),
        technicalControlStatus: SaleTechnicalControlStatus.favorable,
        csaIssuedAt: DateTime(2026, 7, 26),
        histovecShared: true,
        invoicesAvailable: true,
        spareKeyCount: 2,
        cessionMethod: SaleCessionMethod.simplimmat,
      ),
      context: _context(),
      now: DateTime(2026, 8, 5),
    );

    expect(assessment.blockingCount, 0);
    expect(assessment.expectedNetAtAsking, 11550);
    expect(assessment.expectedNetAtMinimum, 10550);
    expect(assessment.negotiationMargin, 1000);
    expect(assessment.technicalControlExpiresAt, DateTime(2026, 9, 1));
    expect(assessment.csaExpiresAt, DateTime(2026, 8, 9));
  });

  test('blocks an expired administrative certificate', () {
    final assessment = SalePreparationCalculator.assess(
      vehicle: _vehicle(year: 2018),
      profile: _profile(
        technicalControlDate: DateTime(2026, 4, 1),
        technicalControlStatus: SaleTechnicalControlStatus.favorable,
        csaIssuedAt: DateTime(2026, 7, 20),
      ),
      context: _context(),
      now: DateTime(2026, 8, 5),
    );

    expect(
      assessment.items.firstWhere((item) => item.code == 'CSA').level,
      SaleChecklistLevel.blocking,
    );
  });

  test('requires a usable technical control for an older private car', () {
    final assessment = SalePreparationCalculator.assess(
      vehicle: _vehicle(year: 2016),
      profile: _profile(csaIssuedAt: DateTime(2026, 8, 1)),
      context: _context(),
      now: DateTime(2026, 8, 5),
    );

    expect(assessment.technicalControlRequired, isTrue);
    expect(
      assessment.items
          .firstWhere((item) => item.code == 'TECHNICAL_CONTROL')
          .level,
      SaleChecklistLevel.blocking,
    );
  });

  test('does not require a technical control for a professional buyer', () {
    final assessment = SalePreparationCalculator.assess(
      vehicle: _vehicle(year: 2010),
      profile: _profile(
        buyerType: SaleBuyerType.automotiveProfessional,
        csaIssuedAt: DateTime(2026, 8, 1),
      ),
      context: _context(),
      now: DateTime(2026, 8, 5),
    );

    expect(assessment.technicalControlRequired, isFalse);
    expect(
      assessment.items
          .firstWhere((item) => item.code == 'TECHNICAL_CONTROL')
          .level,
      SaleChecklistLevel.ready,
    );
  });

  test('blocks a critical technical-control result', () {
    final assessment = SalePreparationCalculator.assess(
      vehicle: _vehicle(year: 2012),
      profile: _profile(
        technicalControlDate: DateTime(2026, 8, 1),
        technicalControlStatus: SaleTechnicalControlStatus.criticalDefects,
        csaIssuedAt: DateTime(2026, 8, 1),
      ),
      context: _context(),
      now: DateTime(2026, 8, 5),
    );

    expect(
      assessment.items
          .firstWhere((item) => item.code == 'TECHNICAL_CONTROL')
          .level,
      SaleChecklistLevel.blocking,
    );
  });

  test('uses calendar months for a control issued on month end', () {
    final assessment = SalePreparationCalculator.assess(
      vehicle: _vehicle(year: 2015),
      profile: _profile(
        technicalControlDate: DateTime(2026, 8, 31),
        technicalControlStatus: SaleTechnicalControlStatus.favorable,
        csaIssuedAt: DateTime(2026, 8, 31),
      ),
      context: _context(),
      now: DateTime(2026, 9, 1),
    );

    expect(assessment.technicalControlExpiresAt, DateTime(2027, 2, 28));
  });

  test('blocks a vehicle that the user does not own', () {
    final assessment = SalePreparationCalculator.assess(
      vehicle: _vehicle(year: 2024),
      profile: _profile(ownsVehicle: false, csaIssuedAt: DateTime(2026, 8, 1)),
      context: _context(),
      now: DateTime(2026, 8, 5),
    );

    expect(
      assessment.items.firstWhere((item) => item.code == 'OWNERSHIP').level,
      SaleChecklistLevel.blocking,
    );
  });
}

Vehicle _vehicle({required int year}) {
  return Vehicle(
    id: 'vehicle-1',
    userId: 'user-1',
    make: 'Renault',
    model: 'Clio',
    vehicleYear: year,
    mileage: 84000,
    registrationNumber: 'AB-123-CD',
    vin: 'VF1AAAAAAAAAAAAAA',
    isPrimary: true,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2026),
  );
}

SalePreparationProfile _profile({
  SaleBuyerType buyerType = SaleBuyerType.privateIndividual,
  double askingPrice = 10000,
  double minimumPrice = 9000,
  double preparationCost = 0,
  bool ownsVehicle = true,
  bool registrationAvailable = true,
  bool coHoldersReady = true,
  DateTime? technicalControlDate,
  SaleTechnicalControlStatus technicalControlStatus =
      SaleTechnicalControlStatus.unknown,
  DateTime? csaIssuedAt,
  bool histovecShared = false,
  bool invoicesAvailable = false,
  int spareKeyCount = 1,
  SaleCessionMethod cessionMethod = SaleCessionMethod.franceTitres,
}) {
  return SalePreparationProfile(
    buyerType: buyerType,
    askingPrice: askingPrice,
    minimumPrice: minimumPrice,
    preparationCost: preparationCost,
    ownsVehicle: ownsVehicle,
    registrationAvailable: registrationAvailable,
    coHoldersReady: coHoldersReady,
    technicalControlDate: technicalControlDate,
    technicalControlStatus: technicalControlStatus,
    csaIssuedAt: csaIssuedAt,
    histovecShared: histovecShared,
    invoicesAvailable: invoicesAvailable,
    spareKeyCount: spareKeyCount,
    cessionMethod: cessionMethod,
  );
}

SalePreparationContext _context() {
  return const SalePreparationContext(
    completedDocumentCount: 3,
    saleReadinessScore: 82,
    overdueMaintenanceCount: 0,
    recentConfirmedEventCount: 6,
  );
}
