class VehicleIdentificationResult {
  const VehicleIdentificationResult({
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.sourceLabel,
    this.vehicleYear,
    this.fuelType,
  });

  final String registrationNumber;
  final String make;
  final String model;
  final int? vehicleYear;
  final String? fuelType;
  final String sourceLabel;

  String get displayName => '$make $model'.trim();

  factory VehicleIdentificationResult.fromMap(Map<String, dynamic> map) {
    final registration = map['registration_number']?.toString().trim() ?? '';
    final make = map['make']?.toString().trim() ?? '';
    final model = map['model']?.toString().trim() ?? '';

    if (registration.isEmpty || make.isEmpty || model.isEmpty) {
      throw const FormatException('Identification véhicule incomplète.');
    }

    return VehicleIdentificationResult(
      registrationNumber: registration,
      make: make,
      model: model,
      vehicleYear: _nullableInt(map['vehicle_year']),
      fuelType: _nullableText(map['fuel_type']),
      sourceLabel: _nullableText(map['source_label']) ?? 'Source véhicule',
    );
  }

  static int? _nullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
