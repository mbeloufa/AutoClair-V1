import '../vehicles/vehicle.dart';

class FuelPriceCatalog {
  static const fuelTypes = <String>[
    'Gazole',
    'SP95',
    'SP98',
    'E10',
    'E85',
    'GPLc',
  ];

  static String? defaultFuelForVehicle(Vehicle? vehicle) {
    final fuelType = _normalize(vehicle?.fuelType ?? '');

    if (fuelType.contains('diesel') || fuelType.contains('gazole')) {
      return 'Gazole';
    }
    if (fuelType.contains('gpl')) {
      return 'GPLc';
    }
    if (fuelType.contains('essence') || fuelType.contains('hybride')) {
      return 'E10';
    }

    return null;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u');
  }
}
