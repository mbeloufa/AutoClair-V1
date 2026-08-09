import 'package:autoclair_app/features/sale_preparation/sale_listing_draft.dart';
import 'package:autoclair_app/features/sale_preparation/sale_preparation_models.dart';
import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'builds a factual sale listing from data already known by AutoClair',
    () {
      final draft = SaleListingDraftBuilder.build(
        vehicle: _vehicle(),
        profile: _profile(
          askingPrice: 12500,
          technicalControlStatus: SaleTechnicalControlStatus.favorable,
          histovecShared: true,
          invoicesAvailable: true,
          spareKeyCount: 2,
        ),
        saleContext: const SalePreparationContext(
          completedDocumentCount: 4,
          saleReadinessScore: 88,
          overdueMaintenanceCount: 0,
          recentConfirmedEventCount: 5,
        ),
      );

      expect(draft.title, 'Renault Clio – 2019 – 84 000 km – Essence');
      expect(draft.description, contains('Prix affiché : 12 500 €'));
      expect(draft.description, contains('Énergie : Essence'));
      expect(
        draft.highlights,
        contains('Rapport HistoVec prêt à être partagé'),
      );
      expect(
        draft.highlights,
        contains('Factures ou justificatifs d’entretien disponibles'),
      );
      expect(
        draft.highlights,
        contains('Contrôle technique déclaré favorable'),
      );
      expect(draft.photoOrder.length, 8);

      final publicText = draft.buildCopyText();
      expect(publicText, isNot(contains('AB-123-CD')));
      expect(publicText, isNot(contains('VF1AAAAAAAAAAAAAA')));
      expect(publicText.toLowerCase(), isNot(contains('excellent état')));
      expect(publicText.toLowerCase(), isNot(contains('bonne affaire')));
    },
  );

  test('flags missing information instead of inventing it', () {
    final draft = SaleListingDraftBuilder.build(
      vehicle: _vehicle(year: null, mileage: null, fuelType: null),
      profile: _profile(),
      saleContext: const SalePreparationContext(
        completedDocumentCount: 0,
        saleReadinessScore: 40,
        overdueMaintenanceCount: 2,
        recentConfirmedEventCount: 0,
      ),
    );

    expect(draft.title, 'Renault Clio');
    expect(
      draft.informationToComplete,
      contains('Année ou date de première mise en circulation'),
    );
    expect(draft.informationToComplete, contains('Kilométrage actuel'));
    expect(draft.informationToComplete, contains('Motorisation / énergie'));
    expect(draft.informationToComplete, contains('Prix de vente'));
    expect(
      draft.informationToComplete,
      contains('Situation du contrôle technique'),
    );
    expect(draft.description, isNot(contains('0 km')));
    expect(draft.description, isNot(contains('0 €')));
  });
}

Vehicle _vehicle({
  int? year = 2019,
  int? mileage = 84000,
  String? fuelType = 'Essence',
}) {
  return Vehicle(
    id: 'vehicle-1',
    userId: 'user-1',
    make: 'Renault',
    model: 'Clio',
    vehicleYear: year,
    mileage: mileage,
    fuelType: fuelType,
    registrationNumber: 'AB-123-CD',
    vin: 'VF1AAAAAAAAAAAAAA',
    isPrimary: true,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2026),
  );
}

SalePreparationProfile _profile({
  double askingPrice = 0,
  SaleTechnicalControlStatus technicalControlStatus =
      SaleTechnicalControlStatus.unknown,
  bool histovecShared = false,
  bool invoicesAvailable = false,
  int spareKeyCount = 1,
}) {
  return SalePreparationProfile(
    buyerType: SaleBuyerType.privateIndividual,
    askingPrice: askingPrice,
    minimumPrice: 0,
    preparationCost: 0,
    ownsVehicle: true,
    registrationAvailable: true,
    coHoldersReady: true,
    technicalControlStatus: technicalControlStatus,
    histovecShared: histovecShared,
    invoicesAvailable: invoicesAvailable,
    spareKeyCount: spareKeyCount,
    cessionMethod: SaleCessionMethod.undecided,
  );
}
