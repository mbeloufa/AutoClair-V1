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
    required this.availabilityStatus,
    required this.realtime,
    required this.confidence,
    required this.smartScore,
    required this.recommendationRank,
    required this.recommendationReasons,
    this.capacity,
    this.availableSpaces,
    this.predictedAvailableSpaces,
    this.predictionSamples,
    this.disabledSpaces,
    this.chargingSpaces,
    this.charge,
    this.openingHours,
    this.operatorName,
    this.website,
    this.phone,
    this.maxHeightM,
    this.surface,
    this.availabilityUpdatedAt,
    this.availabilitySource,
    this.providerCode,
    this.externalId,
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
  final int? availableSpaces;
  final int? predictedAvailableSpaces;
  final int? predictionSamples;
  final int? disabledSpaces;
  final int? chargingSpaces;
  final String? charge;
  final String? openingHours;
  final String? operatorName;
  final String? website;
  final String? phone;
  final double? maxHeightM;
  final String? surface;
  final String availabilityStatus;
  final bool realtime;
  final String confidence;
  final DateTime? availabilityUpdatedAt;
  final String? availabilitySource;
  final String? providerCode;
  final String? externalId;
  final double smartScore;
  final int recommendationRank;
  final List<String> recommendationReasons;

  bool get isFree => fee == 'free';
  bool get isPaid => fee == 'paid';
  bool get hasAccessibleSpaces => (disabledSpaces ?? 0) > 0;
  bool get hasChargingSpaces => (chargingSpaces ?? 0) > 0;
  bool get hasContact => phone != null || website != null;
  bool get isRecommended => recommendationRank == 1;
  bool get hasPrediction =>
      predictedAvailableSpaces != null && (predictionSamples ?? 0) >= 3;
  bool get availabilityIsFresh => confidence == 'official_realtime';
  bool get availabilityIsStale => confidence == 'official_stale';
  bool get isOpen => availabilityStatus == 'open';
  bool get isClosed => availabilityStatus == 'closed';
  bool get isFull => availabilityStatus == 'full';
  bool get hasKnownAvailability =>
      availableSpaces != null && (availabilityIsFresh || availabilityIsStale);

  double? get occupancyRate {
    final total = capacity;
    final available = availableSpaces;
    if (total == null || available == null || total <= 0) return null;
    return ((total - available) / total).clamp(0, 1);
  }

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
      if (value == null || value.isEmpty) return 'Payant';

      final uri = Uri.tryParse(value);
      if (uri != null && uri.hasScheme) return 'Payant';
      if (value.length > 48) return 'Tarif à vérifier';

      return value;
    }
    return 'Tarif non renseigné';
  }

  String get capacityLabel {
    final value = capacity;
    return value == null ? 'Capacité non renseignée' : '$value places';
  }

  String get distanceLabel =>
      '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';

  String get availabilityLabel {
    if (isClosed) return 'Fermé';
    if (isFull) return 'Complet';
    if (availabilityStatus == 'unavailable') {
      return 'Temps réel indisponible';
    }
    final available = availableSpaces;
    if (available != null && availabilityIsFresh) {
      return '$available place${available == 1 ? '' : 's'} libre${available == 1 ? '' : 's'}';
    }
    if (available != null && availabilityIsStale) {
      return '$available places — donnée ancienne';
    }
    return 'Disponibilité inconnue';
  }

  String get confidenceLabel {
    return switch (confidence) {
      'official_realtime' => 'Temps réel officiel',
      'official_stale' => 'Donnée officielle ancienne',
      'official_static' => 'Donnée officielle descriptive',
      _ => 'Donnée cartographique',
    };
  }

  String? availabilityAgeLabel(DateTime now) {
    final updatedAt = availabilityUpdatedAt;
    if (updatedAt == null) return null;
    final difference = now.difference(updatedAt.toLocal());
    if (difference.isNegative) return 'mise à jour récente';
    if (difference.inMinutes < 1) return 'mise à jour à l’instant';
    if (difference.inMinutes < 60) {
      return 'mise à jour il y a ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'mise à jour il y a ${difference.inHours} h';
    }
    return 'mise à jour ancienne';
  }

  factory ParkingOffer.fromJson(Map<String, dynamic> json) {
    final reasons = json['recommendation_reasons'];
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
      availableSpaces: _optionalInt(json['available_spaces']),
      predictedAvailableSpaces: _optionalInt(
        json['predicted_available_spaces'],
      ),
      predictionSamples: _optionalInt(json['prediction_samples']),
      disabledSpaces: _optionalInt(json['disabled_spaces']),
      chargingSpaces: _optionalInt(json['charging_spaces']),
      charge: _optionalString(json['charge']),
      openingHours: _optionalString(json['opening_hours']),
      operatorName: _optionalString(json['operator']),
      website: _optionalString(json['website']),
      phone: _optionalString(json['phone']),
      maxHeightM: _optionalDouble(json['max_height_m']),
      surface: _optionalString(json['surface']),
      availabilityStatus:
          _optionalString(json['availability_status']) ?? 'unknown',
      realtime: json['realtime'] == true,
      confidence: _optionalString(json['confidence']) ?? 'osm',
      availabilityUpdatedAt: DateTime.tryParse(
        json['availability_updated_at']?.toString() ?? '',
      ),
      availabilitySource: _optionalString(json['availability_source']),
      providerCode: _optionalString(json['provider_code']),
      externalId: _optionalString(json['external_id']),
      smartScore: _optionalDouble(json['smart_score']) ?? 0,
      recommendationRank: _optionalInt(json['recommendation_rank']) ?? 0,
      recommendationReasons: reasons is List
          ? reasons
                .map((value) => value?.toString().trim() ?? '')
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const [],
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
    final match = RegExp(r'-?\d+').firstMatch(value.toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}

class ParkingProviderSummary {
  const ParkingProviderSummary({
    required this.code,
    required this.name,
    required this.status,
    required this.records,
    required this.realtime,
    this.message,
  });

  final String code;
  final String name;
  final String status;
  final int records;
  final bool realtime;
  final String? message;

  bool get succeeded => status == 'ok';

  factory ParkingProviderSummary.fromJson(Map<String, dynamic> json) {
    return ParkingProviderSummary(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      records: ParkingOffer._optionalInt(json['records']) ?? 0,
      realtime: json['realtime'] == true,
      message: ParkingOffer._optionalString(json['message']),
    );
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
    required this.providers,
    required this.realtimeCoverage,
    required this.recommendedParkingId,
    required this.historyEnabled,
    this.osmBase,
  });

  final List<ParkingOffer> offers;
  final bool cacheHit;
  final DateTime? sourceFetchedAt;
  final String sourceName;
  final String availabilityDisclaimer;
  final bool truncated;
  final DateTime? osmBase;
  final List<ParkingProviderSummary> providers;
  final bool realtimeCoverage;
  final String? recommendedParkingId;
  final bool historyEnabled;
}
