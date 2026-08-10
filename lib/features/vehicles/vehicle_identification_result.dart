class VehicleIdentificationResult {
  const VehicleIdentificationResult({
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.sourceLabel,
    this.vehicleYear,
    this.fuelType,
    this.vin,
    this.firstRegistrationDate,
    this.profileId,
    this.retrievedAt,
    this.cached = false,
    this.identity = const <String, dynamic>{},
    this.technical = const <String, dynamic>{},
    this.administrative = const <String, dynamic>{},
    this.aftersales = const <String, dynamic>{},
    this.media = const <String, dynamic>{},
  });

  final String registrationNumber;
  final String make;
  final String model;
  final int? vehicleYear;
  final String? fuelType;
  final String? vin;
  final String? firstRegistrationDate;
  final String sourceLabel;
  final String? profileId;
  final DateTime? retrievedAt;
  final bool cached;
  final Map<String, dynamic> identity;
  final Map<String, dynamic> technical;
  final Map<String, dynamic> administrative;
  final Map<String, dynamic> aftersales;
  final Map<String, dynamic> media;

  String get displayName => '$make $model'.trim();

  factory VehicleIdentificationResult.fromMap(Map<String, dynamic> map) {
    final registration = map['registration_number']?.toString().trim() ?? '';
    final make = map['make']?.toString().trim() ?? '';
    final model = map['model']?.toString().trim() ?? '';

    if (registration.isEmpty || make.isEmpty || model.isEmpty) {
      throw const FormatException('Identification véhicule incomplète.');
    }

    final details = _map(map['details']);

    return VehicleIdentificationResult(
      registrationNumber: registration,
      make: make,
      model: model,
      vehicleYear: _nullableInt(map['vehicle_year']),
      fuelType: _nullableText(map['fuel_type']),
      vin: _nullableText(map['vin']),
      firstRegistrationDate: _nullableText(map['first_registration_date']),
      sourceLabel: _nullableText(map['source_label']) ?? 'Source véhicule',
      profileId: _nullableText(map['profile_id']),
      retrievedAt: DateTime.tryParse(map['retrieved_at']?.toString() ?? ''),
      cached: map['cached'] == true,
      identity: _map(details['identity']),
      technical: _map(details['technical']),
      administrative: _map(details['administrative']),
      aftersales: _map(details['aftersales']),
      media: _map(details['media']),
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

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }
}
