class VehicleIdentificationProfile {
  const VehicleIdentificationProfile({
    required this.id,
    required this.registrationNumber,
    required this.sourceLabel,
    required this.retrievedAt,
    required this.identity,
    required this.technical,
    required this.administrative,
    required this.aftersales,
    required this.media,
    this.vehicleId,
    this.vin,
  });

  final String id;
  final String? vehicleId;
  final String registrationNumber;
  final String? vin;
  final String sourceLabel;
  final DateTime retrievedAt;
  final Map<String, dynamic> identity;
  final Map<String, dynamic> technical;
  final Map<String, dynamic> administrative;
  final Map<String, dynamic> aftersales;
  final Map<String, dynamic> media;

  factory VehicleIdentificationProfile.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString().trim() ?? '';
    final registration = map['registration_number']?.toString().trim() ?? '';
    final retrievedAt = DateTime.tryParse(
      map['retrieved_at']?.toString() ?? '',
    );

    if (id.isEmpty || registration.isEmpty || retrievedAt == null) {
      throw const FormatException('Profil véhicule incomplet.');
    }

    return VehicleIdentificationProfile(
      id: id,
      vehicleId: _text(map['vehicle_id']),
      registrationNumber: registration,
      vin: _text(map['vin']),
      sourceLabel: _text(map['source_label']) ?? 'API Plaque Immatriculation',
      retrievedAt: retrievedAt,
      identity: _map(map['identity']),
      technical: _map(map['technical']),
      administrative: _map(map['administrative']),
      aftersales: _map(map['aftersales']),
      media: _map(map['media']),
    );
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }
}
