class FuelStationOffer {
  const FuelStationOffer({
    required this.stationId,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.fuelType,
    required this.availability,
    required this.automate24h,
    required this.services,
    this.price,
    this.priceUpdatedAt,
    this.outageStartedAt,
    this.sourceFetchedAt,
  });

  final String stationId;
  final String address;
  final String postalCode;
  final String city;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String fuelType;
  final double? price;
  final DateTime? priceUpdatedAt;
  final String availability;
  final DateTime? outageStartedAt;
  final bool automate24h;
  final List<String> services;
  final DateTime? sourceFetchedAt;

  bool get isAvailable => availability == 'available' && price != null;

  bool get isTemporaryOutage => availability == 'temporary_outage';

  bool get isDefinitiveOutage => availability == 'definitive_outage';

  String get stationLabel => 'Station-service';

  String get fullAddress {
    final parts = <String>[
      address.trim(),
      [
        postalCode.trim(),
        city.trim(),
      ].where((part) => part.isNotEmpty).join(' '),
    ].where((part) => part.isNotEmpty).toList(growable: false);

    return parts.join(', ');
  }

  factory FuelStationOffer.fromJson(Map<String, dynamic> json) {
    return FuelStationOffer(
      stationId: _requiredString(json['station_id'], 'station_id'),
      address: _optionalString(json['address']) ?? '',
      postalCode: _optionalString(json['postal_code']) ?? '',
      city: _optionalString(json['city']) ?? '',
      latitude: _requiredDouble(json['latitude'], 'latitude'),
      longitude: _requiredDouble(json['longitude'], 'longitude'),
      distanceKm: _requiredDouble(json['distance_km'], 'distance_km'),
      fuelType: _requiredString(json['fuel_type'], 'fuel_type'),
      price: _optionalDouble(json['price']),
      priceUpdatedAt: _optionalDateTime(json['price_updated_at']),
      availability: _optionalString(json['availability']) ?? 'unknown',
      outageStartedAt: _optionalDateTime(json['outage_started_at']),
      automate24h: json['automate_24h'] == true,
      services: _stringList(json['services']),
      sourceFetchedAt: _optionalDateTime(json['source_fetched_at']),
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

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];

    return List<String>.unmodifiable(
      value
          .map((item) => item?.toString().trim())
          .whereType<String>()
          .where((item) => item.isNotEmpty),
    );
  }
}

class FuelSearchResult {
  const FuelSearchResult({
    required this.offers,
    required this.cacheHit,
    required this.sourceFetchedAt,
    required this.truncated,
  });

  final List<FuelStationOffer> offers;
  final bool cacheHit;
  final DateTime? sourceFetchedAt;
  final bool truncated;
}
