class TechnicalControlOffer {
  const TechnicalControlOffer({
    required this.centerSiret,
    required this.denomination,
    required this.distanceKm,
    required this.vehicleCategoryId,
    required this.vehicleCategoryLabel,
    required this.energyCategoryId,
    required this.energyCategoryLabel,
    required this.inspectionPrice,
    this.address,
    this.postalCode,
    this.city,
    this.phone,
    this.website,
    this.latitude,
    this.longitude,
    this.reinspectionMinPrice,
    this.reinspectionMaxPrice,
    this.tariffUpdatedAt,
  });

  final String centerSiret;
  final String denomination;
  final String? address;
  final String? postalCode;
  final String? city;
  final String? phone;
  final String? website;
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final String vehicleCategoryId;
  final String vehicleCategoryLabel;
  final String energyCategoryId;
  final String energyCategoryLabel;
  final double inspectionPrice;
  final double? reinspectionMinPrice;
  final double? reinspectionMaxPrice;
  final DateTime? tariffUpdatedAt;

  String get cityLine {
    final values = <String>[
      if (postalCode?.trim().isNotEmpty == true) postalCode!.trim(),
      if (city?.trim().isNotEmpty == true) city!.trim(),
    ];
    return values.join(' ');
  }

  String get fullAddress {
    final values = <String>[
      if (address?.trim().isNotEmpty == true) address!.trim(),
      if (cityLine.isNotEmpty) cityLine,
    ];
    return values.join(', ');
  }

  factory TechnicalControlOffer.fromJson(Map<String, dynamic> json) {
    return TechnicalControlOffer(
      centerSiret: _requiredText(json['center_siret'], 'center_siret'),
      denomination: _requiredText(json['denomination'], 'denomination'),
      address: _optionalText(json['address']),
      postalCode: _optionalText(json['postal_code']),
      city: _optionalText(json['city']),
      phone: _optionalText(json['phone']),
      website: _optionalText(json['website']),
      latitude: _optionalDouble(json['latitude']),
      longitude: _optionalDouble(json['longitude']),
      distanceKm: _requiredDouble(json['distance_km'], 'distance_km'),
      vehicleCategoryId: _requiredText(
        json['vehicle_category_id'],
        'vehicle_category_id',
      ),
      vehicleCategoryLabel: _requiredText(
        json['vehicle_category_label'],
        'vehicle_category_label',
      ),
      energyCategoryId: _requiredText(
        json['energy_category_id'],
        'energy_category_id',
      ),
      energyCategoryLabel: _requiredText(
        json['energy_category_label'],
        'energy_category_label',
      ),
      inspectionPrice: _requiredDouble(
        json['inspection_price'],
        'inspection_price',
      ),
      reinspectionMinPrice: _optionalDouble(json['reinspection_min_price']),
      reinspectionMaxPrice: _optionalDouble(json['reinspection_max_price']),
      tariffUpdatedAt: _optionalDateTime(json['tariff_updated_at']),
    );
  }

  static String _requiredText(Object? value, String field) {
    final text = _optionalText(value);
    if (text == null) {
      throw FormatException('Champ obligatoire absent : $field');
    }
    return text;
  }

  static String? _optionalText(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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
}
