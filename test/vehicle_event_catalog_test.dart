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
}
