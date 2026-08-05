import 'package:autoclair_app/features/vehicles/vehicle_brand_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleBrandCatalog', () {
    test('normalise les alias courants', () {
      expect(VehicleBrandCatalog.displayName('VW'), 'Volkswagen');
      expect(VehicleBrandCatalog.displayName('Citroen'), 'Citroën');
      expect(VehicleBrandCatalog.displayName('Skoda'), 'Škoda');
      expect(VehicleBrandCatalog.displayName('Mercedes Benz'), 'Mercedes-Benz');
    });

    test('associe les logos des principales marques', () {
      expect(VehicleBrandCatalog.definitionFor('Audi')?.icon, isNotNull);
      expect(VehicleBrandCatalog.definitionFor('Renault')?.icon, isNotNull);
      expect(VehicleBrandCatalog.definitionFor('Peugeot')?.icon, isNotNull);
      expect(VehicleBrandCatalog.definitionFor('Volkswagen')?.icon, isNotNull);
      expect(VehicleBrandCatalog.definitionFor('Toyota')?.icon, isNotNull);
    });

    test('conserve une marque non référencée', () {
      expect(VehicleBrandCatalog.canonicalValue('Lancia'), 'Lancia');
      expect(VehicleBrandCatalog.displayName('Lancia'), 'Lancia');
      expect(VehicleBrandCatalog.initials('Lancia'), 'LA');
    });

    test('la recherche prend en charge les accents et alias', () {
      expect(VehicleBrandCatalog.search('citroen').single.name, 'Citroën');
      expect(VehicleBrandCatalog.search('vw').single.name, 'Volkswagen');
    });
  });
}
