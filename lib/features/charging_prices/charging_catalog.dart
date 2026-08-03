import '../vehicles/vehicle.dart';

class ChargingConnectorOption {
  const ChargingConnectorOption({
    required this.id,
    required this.label,
    required this.iconLabel,
  });

  final String id;
  final String label;
  final String iconLabel;
}

class ChargingCatalog {
  static const connectors = <ChargingConnectorOption>[
    ChargingConnectorOption(
      id: 'any',
      label: 'Tous les connecteurs',
      iconLabel: 'Tous',
    ),
    ChargingConnectorOption(id: 'type2', label: 'Type 2', iconLabel: 'T2'),
    ChargingConnectorOption(id: 'ccs', label: 'Combo CCS', iconLabel: 'CCS'),
    ChargingConnectorOption(
      id: 'chademo',
      label: 'CHAdeMO',
      iconLabel: 'CHAdeMO',
    ),
    ChargingConnectorOption(id: 'ef', label: 'Prise E/F', iconLabel: 'E/F'),
    ChargingConnectorOption(id: 'other', label: 'Autre', iconLabel: 'Autre'),
  ];

  static const minimumPowersKw = <double>[0, 7, 22, 50, 100, 150];
  static const energyChoicesKwh = <double>[10, 20, 40, 60];
  static const radiusChoicesKm = <double>[5, 10, 20, 30, 50];

  static bool isElectricVehicle(Vehicle? vehicle) {
    final fuel = _normalize(vehicle?.fuelType ?? '');
    return fuel.contains('electri') || fuel.contains('hybride rechargeable');
  }

  static String defaultConnectorForVehicle(Vehicle? vehicle) {
    if (!isElectricVehicle(vehicle)) return 'any';
    return 'any';
  }

  static String connectorLabel(String id) {
    for (final option in connectors) {
      if (option.id == id) return option.label;
    }
    return 'Tous les connecteurs';
  }

  static String powerLabel(double powerKw) {
    if (powerKw <= 0) return 'Toutes puissances';
    return '${powerKw.toStringAsFixed(0)} kW et plus';
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
