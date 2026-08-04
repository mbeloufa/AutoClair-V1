class ParkingOffer {
  const ParkingOffer({
    required this.parkingId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.parkingType,
    required this.access,
    required this.fee,
    required this.parkAndRide,
    required this.covered,
    required this.sourceKind,
    this.capacity,
    this.disabledSpaces,
    this.chargingSpaces,
    this.charge,
    this.openingHours,
    this.operatorName,
    this.website,
    this.phone,
    this.maxHeightM,
    this.surface,
  });

  final String parkingId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String parkingType;
  final String access;
  final String fee;
  final bool parkAndRide;
  final bool covered;
  final String sourceKind;
  final int? capacity;
  final int? disabledSpaces;
  final int? chargingSpaces;
  final String? charge;
  final String? openingHours;
  final String? operatorName;
  final String? website;
  final String? phone;
  final double? maxHeightM;
  final String? surface;

  bool get isFree => fee == 'free';

  bool get isPaid => fee == 'paid';

  bool get hasAccessibleSpaces => (disabledSpaces ?? 0) > 0;

  bool get hasChargingSpaces => (chargingSpaces ?? 0) > 0;

  bool get hasContact => phone != null || website != null;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return sourceKind == 'entrance' ? 'Entrée de parking' : 'Parking';
  }

  String get typeLabel {
    return switch (parkingType) {
      'underground' => 'Parking souterrain',
      'multi-storey' => 'Parking à étages',
      'rooftop' => 'Parking en toiture',
      'surface' => 'Parking de surface',
      'street_side' => 'Stationnement latéral',
      'lane' => 'Stationnement sur voirie',
      'on_street' => 'Stationnement sur voirie',
      'on_kerb' => 'Stationnement sur trottoir',
      'half_on_kerb' => 'Stationnement semi-trottoir',
      'carports' => 'Parking couvert',
      'garage_boxes' => 'Box de stationnement',
      _ => sourceKind == 'entrance' ? 'Entrée de parking' : 'Parking',
    };
  }

  String get accessLabel {
    return switch (access) {
      'customers' => 'Réservé aux clients',
      'destination' => 'Réservé à la destination',
      'permissive' => 'Accès autorisé',
      'yes' => 'Accès public',
      _ => 'Accès à vérifier',
    };
  }

  String get feeLabel {
    if (isFree) return 'Gratuit';
    if (isPaid) {
      final value = charge?.trim();
      return value == null || value.isEmpty ? 'Payant' : value;
    }
    return 'Tarif non renseigné';
  }

  String get capacityLabel {
    final value = capacity;
    return value == null ? 'Capacité non renseignée' : '$value places';
  }

  String get distanceLabel =>
      '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';

  factory ParkingOffer.fromJson(Map<String, dynamic> json) {
    return ParkingOffer(
      parkingId: _requiredString(json['parking_id'], 'parking_id'),
      name: _optionalString(json['name']) ?? '',
      address: _optionalString(json['address']) ?? '',
      latitude: _requiredDouble(json['latitude'], 'latitude'),
      longitude: _requiredDouble(json['longitude'], 'longitude'),
      distanceKm: _requiredDouble(json['distance_km'], 'distance_km'),
      parkingType: _optionalString(json['parking_type']) ?? 'unknown',
      access: _optionalString(json['access']) ?? 'unknown',
      fee: _optionalString(json['fee']) ?? 'unknown',
      parkAndRide: json['park_and_ride'] == true,
      covered: json['covered'] == true,
      sourceKind: _optionalString(json['source_kind']) ?? 'facility',
      capacity: _optionalInt(json['capacity']),
      disabledSpaces: _optionalInt(json['disabled_spaces']),
      chargingSpaces: _optionalInt(json['charging_spaces']),
      charge: _optionalString(json['charge']),
      openingHours: _optionalString(json['opening_hours']),
      operatorName: _optionalString(json['operator']),
      website: _optionalString(json['website']),
      phone: _optionalString(json['phone']),
      maxHeightM: _optionalDouble(json['max_height_m']),
      surface: _optionalString(json['surface']),
    );
  }

  static String _requiredString(Object? value, String field) {
    final parsed = _optionalString(value);
    if (parsed == null) {
      throw FormatException('Texte obligatoire invalide : $field');
    }
    return parsed;
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _requiredDouble(Object? value, String field) {
    final parsed = _optionalDouble(value);
    if (parsed == null) {
      throw FormatException('Nombre obligatoire invalide : $field');
    }
    return parsed;
  }

  static double? _optionalDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    final match = RegExp(r'\d+').firstMatch(value.toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}

class ParkingSearchResult {
  const ParkingSearchResult({
    required this.offers,
    required this.cacheHit,
    required this.sourceFetchedAt,
    required this.sourceName,
    required this.availabilityDisclaimer,
    required this.truncated,
    this.osmBase,
  });

  final List<ParkingOffer> offers;
  final bool cacheHit;
  final DateTime? sourceFetchedAt;
  final String sourceName;
  final String availabilityDisclaimer;
  final bool truncated;
  final DateTime? osmBase;
}
