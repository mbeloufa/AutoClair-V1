enum TirePhotoSlot {
  frontLeftTread,
  frontRightTread,
  rearLeftTread,
  rearRightTread,
  frontSidewall,
  rearSidewall,
}

extension TirePhotoSlotX on TirePhotoSlot {
  String get apiValue => switch (this) {
    TirePhotoSlot.frontLeftTread => 'FRONT_LEFT_TREAD',
    TirePhotoSlot.frontRightTread => 'FRONT_RIGHT_TREAD',
    TirePhotoSlot.rearLeftTread => 'REAR_LEFT_TREAD',
    TirePhotoSlot.rearRightTread => 'REAR_RIGHT_TREAD',
    TirePhotoSlot.frontSidewall => 'FRONT_SIDEWALL',
    TirePhotoSlot.rearSidewall => 'REAR_SIDEWALL',
  };

  String get shortLabel => switch (this) {
    TirePhotoSlot.frontLeftTread => 'AVG',
    TirePhotoSlot.frontRightTread => 'AVD',
    TirePhotoSlot.rearLeftTread => 'ARG',
    TirePhotoSlot.rearRightTread => 'ARD',
    TirePhotoSlot.frontSidewall => 'Flanc AV',
    TirePhotoSlot.rearSidewall => 'Flanc AR',
  };

  bool get isTread => index <= TirePhotoSlot.rearRightTread.index;
}

enum TireInspectionLevel {
  ok,
  watch,
  replaceSoon,
  replaceNow,
  urgentProfessionalCheck,
  unknown,
}

TireInspectionLevel tireInspectionLevelFromApi(String? value) =>
    switch (value) {
      'OK' => TireInspectionLevel.ok,
      'WATCH' => TireInspectionLevel.watch,
      'REPLACE_SOON' => TireInspectionLevel.replaceSoon,
      'REPLACE_NOW' => TireInspectionLevel.replaceNow,
      'URGENT_PROFESSIONAL_CHECK' =>
        TireInspectionLevel.urgentProfessionalCheck,
      _ => TireInspectionLevel.unknown,
    };

String tireInspectionLevelLabel(TireInspectionLevel value) => switch (value) {
  TireInspectionLevel.ok => 'Aucun défaut évident détecté',
  TireInspectionLevel.watch => 'À surveiller',
  TireInspectionLevel.replaceSoon => 'Remplacement à prévoir',
  TireInspectionLevel.replaceNow => 'Remplacement recommandé rapidement',
  TireInspectionLevel.urgentProfessionalCheck =>
    'Contrôle professionnel urgent',
  TireInspectionLevel.unknown => 'Analyse insuffisante',
};

class TireWheelAssessment {
  const TireWheelAssessment({
    required this.position,
    required this.level,
    required this.confidence,
    required this.treadAssessment,
    required this.visibleFindings,
    required this.retakeRequired,
    this.retakeReason,
  });

  factory TireWheelAssessment.fromJson(Map<String, dynamic> json) {
    return TireWheelAssessment(
      position: json['position']?.toString() ?? '',
      level: tireInspectionLevelFromApi(json['condition']?.toString()),
      confidence: json['confidence']?.toString() ?? 'LOW',
      treadAssessment: json['tread_assessment']?.toString() ?? '',
      visibleFindings: _stringList(json['visible_findings']),
      retakeRequired: json['retake_required'] == true,
      retakeReason: _nullableText(json['retake_reason']),
    );
  }

  final String position;
  final TireInspectionLevel level;
  final String confidence;
  final String treadAssessment;
  final List<String> visibleFindings;
  final bool retakeRequired;
  final String? retakeReason;
}

class TireSidewallAssessment {
  const TireSidewallAssessment({
    required this.axle,
    required this.tireType,
    required this.markings,
    required this.confidence,
    required this.retakeRequired,
    this.dimension,
    this.loadSpeedIndex,
    this.brand,
    this.model,
    this.dotCode,
    this.retakeReason,
  });

  factory TireSidewallAssessment.fromJson(Map<String, dynamic> json) {
    return TireSidewallAssessment(
      axle: json['axle']?.toString() ?? '',
      dimension: _nullableText(json['dimension']),
      loadSpeedIndex: _nullableText(json['load_speed_index']),
      brand: _nullableText(json['brand']),
      model: _nullableText(json['model']),
      tireType: json['tire_type']?.toString() ?? 'UNKNOWN',
      markings: _stringList(json['markings']),
      dotCode: _nullableText(json['dot_code']),
      confidence: json['confidence']?.toString() ?? 'LOW',
      retakeRequired: json['retake_required'] == true,
      retakeReason: _nullableText(json['retake_reason']),
    );
  }

  final String axle;
  final String? dimension;
  final String? loadSpeedIndex;
  final String? brand;
  final String? model;
  final String tireType;
  final List<String> markings;
  final String? dotCode;
  final String confidence;
  final bool retakeRequired;
  final String? retakeReason;
}

class TirePhotoQuality {
  const TirePhotoQuality({
    required this.slot,
    required this.status,
    required this.reason,
  });

  factory TirePhotoQuality.fromJson(Map<String, dynamic> json) {
    return TirePhotoQuality(
      slot: json['slot']?.toString() ?? '',
      status: json['status']?.toString() ?? 'RETAKE',
      reason: json['reason']?.toString() ?? '',
    );
  }

  final String slot;
  final String status;
  final String reason;
}

class TireInspectionResult {
  const TireInspectionResult({
    required this.status,
    required this.globalLevel,
    required this.summary,
    required this.professionalMessage,
    required this.replacementRecommended,
    required this.wheels,
    required this.sidewalls,
    required this.photoQuality,
    this.frontDimension,
    this.rearDimension,
  });

  factory TireInspectionResult.fromJson(Map<String, dynamic> json) {
    return TireInspectionResult(
      status: json['status']?.toString() ?? 'FAILED',
      globalLevel: tireInspectionLevelFromApi(
        json['global_status']?.toString(),
      ),
      summary: json['summary']?.toString() ?? '',
      professionalMessage: json['professional_message']?.toString() ?? '',
      replacementRecommended: json['replacement_recommended'] == true,
      frontDimension: _nullableText(json['front_dimension']),
      rearDimension: _nullableText(json['rear_dimension']),
      wheels: _maps(
        json['wheels'],
      ).map(TireWheelAssessment.fromJson).toList(growable: false),
      sidewalls: _maps(
        json['sidewalls'],
      ).map(TireSidewallAssessment.fromJson).toList(growable: false),
      photoQuality: _maps(
        json['photo_quality'],
      ).map(TirePhotoQuality.fromJson).toList(growable: false),
    );
  }

  final String status;
  final TireInspectionLevel globalLevel;
  final String summary;
  final String professionalMessage;
  final bool replacementRecommended;
  final String? frontDimension;
  final String? rearDimension;
  final List<TireWheelAssessment> wheels;
  final List<TireSidewallAssessment> sidewalls;
  final List<TirePhotoQuality> photoQuality;

  bool get needsRetake =>
      status == 'NEEDS_RETAKE' ||
      photoQuality.any((item) => item.status == 'RETAKE');

  Set<String> get retakeSlots => photoQuality
      .where((item) => item.status == 'RETAKE')
      .map((item) => item.slot)
      .where((item) => item.isNotEmpty)
      .toSet();
}

class TireRetailOffer {
  const TireRetailOffer({
    required this.merchant,
    required this.productName,
    required this.dimension,
    required this.tireType,
    required this.unitPriceEur,
    required this.url,
  });

  factory TireRetailOffer.fromJson(Map<String, dynamic> json) {
    return TireRetailOffer(
      merchant: json['merchant']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      dimension: json['dimension']?.toString() ?? '',
      tireType: json['tire_type']?.toString() ?? 'UNKNOWN',
      unitPriceEur: (json['unit_price_eur'] as num?)?.toDouble() ?? 0,
      url: json['url']?.toString() ?? '',
    );
  }

  final String merchant;
  final String productName;
  final String dimension;
  final String tireType;
  final double unitPriceEur;
  final String url;
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
