import 'package:autoclair_app/features/vehicle_care/vehicle_event_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue reste limité à cinq grandes catégories', () {
    expect(VehicleEventCatalog.categories.length, 5);
    expect(VehicleEventCatalog.categories.map((item) => item.label), [
      'Entretien',
      'Sécurité',
      'Réparation',
      'Administratif',
      'Autre',
    ]);
  });

  test('filtre à huile devient entretien filtres et fluides', () {
    final result = VehicleEventCatalog.classify('Remplacement filtre à huile');
    expect(result.category.label, 'Entretien');
    expect(result.subcategory.label, 'Filtres et fluides');
  });

  test('plaquettes avant deviennent sécurité freinage', () {
    final result = VehicleEventCatalog.classify('Plaquettes de freins AV');
    expect(result.category.label, 'Sécurité');
    expect(result.subcategory.label, 'Freinage');
  });

  test('contrôle technique est classé dans sécurité', () {
    final result = VehicleEventCatalog.classify(
      'Procès-verbal contrôle technique',
    );
    expect(result.category.code, 'SAFETY');
    expect(result.subcategory.code, 'TECHNICAL_INSPECTION');
  });

  _lot3CategorizationTests();
}

// Enrichissements fonctionnels du Lot 3.
void _lot3CategorizationTests() {
  test('contrôle antipollution reste distinct du contrôle technique', () {
    final result = VehicleEventCatalog.classify(
      'Mesure opacité fumée et contrôle antipollution',
    );
    expect(result.category.code, 'SAFETY');
    expect(result.subcategory.code, 'ANTI_POLLUTION');
  });

  test('lecture des codes défaut devient diagnostic', () {
    final result = VehicleEventCatalog.classify(
      'Passage à la valise et lecture code erreur',
    );
    expect(result.category.code, 'REPAIR');
    expect(result.subcategory.code, 'DIAGNOSTICS');
  });

  test('certificat de cession devient achat et vente', () {
    final result = VehicleEventCatalog.classify(
      'Signature du certificat de cession du véhicule',
    );
    expect(result.category.code, 'ADMINISTRATIVE');
    expect(result.subcategory.code, 'PURCHASE_SALE');
  });

  test('roulement reste direction et suspension, pas pneus', () {
    final result = VehicleEventCatalog.classify(
      'Remplacement du roulement avant',
    );
    expect(result.category.code, 'REPAIR');
    expect(result.subcategory.code, 'STEERING_SUSPENSION');
  });

  test('un libellé ambigu reste dans autre', () {
    final result = VehicleEventCatalog.classify('À vérifier prochainement');
    expect(result.category.code, 'OTHER');
    expect(result.subcategory.code, 'OTHER');
  });
}
