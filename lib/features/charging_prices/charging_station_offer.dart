class ChargingStationOffer {
  const ChargingStationOffer({
    required this.stationId,
    required this.stationName,
    required this.networkName,
    required this.operatorName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.maxPowerKw,
    required this.connectors,
    required this.pointCount,
    required this.isFree,
    required this.pricingKind,
    required this.pricingComparable,
    required this.paymentAtTerminal,
    required this.paymentCard,
    required this.paymentOther,
    required this.reservation,
    this.operatorPhone,
    this.unitPricePerKwh,
    this.sessionFee,
    this.estimatedCost,
    this.tariffText,
    this.accessCondition,
    this.hours,
    this.accessibility,
    this.updatedAt,
  });

  final String stationId;
  final String stationName;
  final String networkName;
  final String operatorName;
  final String? operatorPhone;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double maxPowerKw;
  final List<String> connectors;
  final int pointCount;
  final bool isFree;
  final String pricingKind;
  final bool pricingComparable;
  final double? unitPricePerKwh;
  final double? sessionFee;
  final double? estimatedCost;
  final String? tariffText;
  final bool paymentAtTerminal;
  final bool paymentCard;
  final bool paymentOther;
  final String? accessCondition;
  final bool reservation;
  final String? hours;
  final String? accessibility;
  final DateTime? updatedAt;

  bool get hasPhone => operatorPhone?.trim().isNotEmpty == true;

  bool get hasTariffText => tariffText?.trim().isNotEmpty == true;

  String get displayName {
    final name = stationName.trim();
    if (name.isNotEmpty && name.toLowerCase() != 'station de recharge') {
      return name;
    }
    final network = networkName.trim();
    return network.isEmpty ? 'Station de recharge' : network;
  }

  String get secondaryName {
    final candidates = <String>[networkName, operatorName]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .where((value) => value != displayName)
        .toList(growable: false);
    return candidates.isEmpty ? '' : candidates.join(' • ');
  }

  String pricingLabel(double energyKwh) {
    if (isFree || pricingKind == 'free') return 'Gratuit';
    if (pricingComparable && estimatedCost != null) {
      return '≈ ${_money(estimatedCost!)} €';
    }
    return 'Tarif non comparable';
  }

  String pricingDetail(double energyKwh) {
    if (isFree || pricingKind == 'free') {
      return 'Recharge déclarée gratuite';
    }
    if (pricingComparable && unitPricePerKwh != null) {
      final parts = <String>[
        '${_money(unitPricePerKwh!)} €/kWh',
        if ((sessionFee ?? 0) > 0) '${_money(sessionFee!)} € de session',
      ];
      return '${parts.join(' + ')} • estimation pour ${energyKwh.toStringAsFixed(0)} kWh';
    }
    return 'Consultez le tarif publié par l’opérateur';
  }

  factory ChargingStationOffer.fromJson(Map<String, dynamic> json) {
    return ChargingStationOffer(
      stationId: _requiredString(json['station_id'], 'station_id'),
      stationName:
          _optionalString(json['station_name']) ?? 'Station de recharge',
      networkName:
          _optionalString(json['network_name']) ?? 'Réseau non renseigné',
      operatorName:
          _optionalString(json['operator_name']) ?? 'Opérateur non renseigné',
      operatorPhone: _optionalString(json['operator_phone']),
      address: _optionalString(json['address']) ?? 'Adresse non renseignée',
      latitude: _requiredDouble(json['latitude'], 'latitude'),
      longitude: _requiredDouble(json['longitude'], 'longitude'),
      distanceKm: _requiredDouble(json['distance_km'], 'distance_km'),
      maxPowerKw: _requiredDouble(json['max_power_kw'], 'max_power_kw'),
      connectors: _stringList(json['connectors']),
      pointCount: _requiredInt(json['point_count'], 'point_count'),
      isFree: json['is_free'] == true,
      pricingKind: _optionalString(json['pricing_kind']) ?? 'unknown',
      pricingComparable: json['pricing_comparable'] == true,
      unitPricePerKwh: _optionalDouble(json['unit_price_per_kwh']),
      sessionFee: _optionalDouble(json['session_fee']),
      estimatedCost: _optionalDouble(json['estimated_cost']),
      tariffText: _optionalString(json['tariff_text']),
      paymentAtTerminal: json['payment_at_terminal'] == true,
      paymentCard: json['payment_card'] == true,
      paymentOther: json['payment_other'] == true,
      accessCondition: _optionalString(json['access_condition']),
      reservation: json['reservation'] == true,
      hours: _optionalString(json['hours']),
      accessibility: _optionalString(json['accessibility']),
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  static String _money(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

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

  static int _requiredInt(Object? value, String field) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('Entier obligatoire invalide : $field');
    }
    return parsed;
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

class ChargingSearchResult {
  const ChargingSearchResult({
    required this.offers,
    required this.cacheHit,
    required this.sourceFetchedAt,
    required this.truncated,
    required this.energyKwh,
    required this.pricingDisclaimer,
    required this.sourceName,
  });

  final List<ChargingStationOffer> offers;
  final bool cacheHit;
  final DateTime? sourceFetchedAt;
  final bool truncated;
  final double energyKwh;
  final String pricingDisclaimer;
  final String sourceName;
}
