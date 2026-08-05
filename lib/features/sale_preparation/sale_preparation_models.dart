import '../vehicles/vehicle.dart';

enum SaleBuyerType { privateIndividual, automotiveProfessional }

extension SaleBuyerTypeX on SaleBuyerType {
  String get databaseValue => switch (this) {
    SaleBuyerType.privateIndividual => 'PRIVATE_INDIVIDUAL',
    SaleBuyerType.automotiveProfessional => 'AUTOMOTIVE_PROFESSIONAL',
  };

  String get label => switch (this) {
    SaleBuyerType.privateIndividual => 'Particulier',
    SaleBuyerType.automotiveProfessional => 'Professionnel automobile',
  };
}

enum SaleTechnicalControlStatus {
  unknown,
  favorable,
  majorDefects,
  criticalDefects,
  notRequired,
}

extension SaleTechnicalControlStatusX on SaleTechnicalControlStatus {
  String get databaseValue => switch (this) {
    SaleTechnicalControlStatus.unknown => 'UNKNOWN',
    SaleTechnicalControlStatus.favorable => 'FAVORABLE',
    SaleTechnicalControlStatus.majorDefects => 'MAJOR_DEFECTS',
    SaleTechnicalControlStatus.criticalDefects => 'CRITICAL_DEFECTS',
    SaleTechnicalControlStatus.notRequired => 'NOT_REQUIRED',
  };

  String get label => switch (this) {
    SaleTechnicalControlStatus.unknown => 'À vérifier',
    SaleTechnicalControlStatus.favorable => 'Favorable',
    SaleTechnicalControlStatus.majorDefects =>
      'Défaillances majeures / contre-visite',
    SaleTechnicalControlStatus.criticalDefects => 'Défaillance critique',
    SaleTechnicalControlStatus.notRequired => 'Non requis',
  };
}

enum SaleCessionMethod { undecided, simplimmat, franceTitres }

extension SaleCessionMethodX on SaleCessionMethod {
  String get databaseValue => switch (this) {
    SaleCessionMethod.undecided => 'UNDECIDED',
    SaleCessionMethod.simplimmat => 'SIMPLIMMAT',
    SaleCessionMethod.franceTitres => 'FRANCE_TITRES',
  };

  String get label => switch (this) {
    SaleCessionMethod.undecided => 'À décider',
    SaleCessionMethod.simplimmat => 'Simplimmat',
    SaleCessionMethod.franceTitres => 'France Titres / certificat de cession',
  };
}

enum SaleChecklistLevel { ready, warning, blocking, optional }

extension SaleChecklistLevelX on SaleChecklistLevel {
  String get label => switch (this) {
    SaleChecklistLevel.ready => 'Prêt',
    SaleChecklistLevel.warning => 'À vérifier',
    SaleChecklistLevel.blocking => 'Bloquant',
    SaleChecklistLevel.optional => 'Recommandé',
  };
}

class SalePreparationProfile {
  const SalePreparationProfile({
    required this.buyerType,
    required this.askingPrice,
    required this.minimumPrice,
    required this.preparationCost,
    required this.ownsVehicle,
    required this.registrationAvailable,
    required this.coHoldersReady,
    required this.technicalControlStatus,
    required this.histovecShared,
    required this.invoicesAvailable,
    required this.spareKeyCount,
    required this.cessionMethod,
    this.technicalControlDate,
    this.csaIssuedAt,
  });

  final SaleBuyerType buyerType;
  final double askingPrice;
  final double minimumPrice;
  final double preparationCost;
  final bool ownsVehicle;
  final bool registrationAvailable;
  final bool coHoldersReady;
  final DateTime? technicalControlDate;
  final SaleTechnicalControlStatus technicalControlStatus;
  final DateTime? csaIssuedAt;
  final bool histovecShared;
  final bool invoicesAvailable;
  final int spareKeyCount;
  final SaleCessionMethod cessionMethod;

  factory SalePreparationProfile.defaults() {
    return const SalePreparationProfile(
      buyerType: SaleBuyerType.privateIndividual,
      askingPrice: 0,
      minimumPrice: 0,
      preparationCost: 0,
      ownsVehicle: true,
      registrationAvailable: true,
      coHoldersReady: true,
      technicalControlStatus: SaleTechnicalControlStatus.unknown,
      histovecShared: false,
      invoicesAvailable: false,
      spareKeyCount: 1,
      cessionMethod: SaleCessionMethod.undecided,
    );
  }

  factory SalePreparationProfile.fromMap(Map<String, dynamic> map) {
    return SalePreparationProfile(
      buyerType: _buyerType(map['buyer_type']),
      askingPrice: _decimal(map['asking_price_eur']),
      minimumPrice: _decimal(map['minimum_price_eur']),
      preparationCost: _decimal(map['preparation_cost_eur']),
      ownsVehicle: map['owns_vehicle'] as bool? ?? true,
      registrationAvailable: map['registration_available'] as bool? ?? false,
      coHoldersReady: map['coholders_ready'] as bool? ?? true,
      technicalControlDate: _date(map['technical_control_date']),
      technicalControlStatus: _technicalControlStatus(
        map['technical_control_status'],
      ),
      csaIssuedAt: _date(map['csa_issued_at']),
      histovecShared: map['histovec_shared'] as bool? ?? false,
      invoicesAvailable: map['invoices_available'] as bool? ?? false,
      spareKeyCount: _integer(map['spare_key_count'], fallback: 1),
      cessionMethod: _cessionMethod(map['cession_method']),
    );
  }

  void validate() {
    if (askingPrice < 0 || askingPrice > 1000000) {
      throw const FormatException(
        'Le prix affiché doit être compris entre 0 et 1 000 000 €.',
      );
    }
    if (minimumPrice < 0 || minimumPrice > 1000000) {
      throw const FormatException(
        'Le prix minimum doit être compris entre 0 et 1 000 000 €.',
      );
    }
    if (minimumPrice > askingPrice) {
      throw const FormatException(
        'Le prix minimum ne peut pas dépasser le prix affiché.',
      );
    }
    if (preparationCost < 0 || preparationCost > 100000) {
      throw const FormatException(
        'Le budget de préparation doit être compris entre 0 et 100 000 €.',
      );
    }
    if (spareKeyCount < 0 || spareKeyCount > 10) {
      throw const FormatException(
        'Le nombre de clés doit être compris entre 0 et 10.',
      );
    }
  }
}

class SalePreparationContext {
  const SalePreparationContext({
    required this.completedDocumentCount,
    required this.saleReadinessScore,
    required this.overdueMaintenanceCount,
    required this.recentConfirmedEventCount,
  });

  final int completedDocumentCount;
  final int saleReadinessScore;
  final int overdueMaintenanceCount;
  final int recentConfirmedEventCount;
}

class SaleChecklistItem {
  const SaleChecklistItem({
    required this.code,
    required this.title,
    required this.detail,
    required this.level,
  });

  final String code;
  final String title;
  final String detail;
  final SaleChecklistLevel level;

  Map<String, dynamic> toMap() => {
    'code': code,
    'title': title,
    'detail': detail,
    'level': level.name.toUpperCase(),
  };
}

class SalePreparationAssessment {
  const SalePreparationAssessment({
    required this.score,
    required this.items,
    required this.blockingCount,
    required this.warningCount,
    required this.expectedNetAtAsking,
    required this.expectedNetAtMinimum,
    required this.negotiationMargin,
    required this.technicalControlRequired,
    required this.technicalControlRequirementUncertain,
    this.technicalControlExpiresAt,
    this.csaExpiresAt,
  });

  final int score;
  final List<SaleChecklistItem> items;
  final int blockingCount;
  final int warningCount;
  final double expectedNetAtAsking;
  final double expectedNetAtMinimum;
  final double negotiationMargin;
  final bool technicalControlRequired;
  final bool technicalControlRequirementUncertain;
  final DateTime? technicalControlExpiresAt;
  final DateTime? csaExpiresAt;

  bool get canFinalize => blockingCount == 0;

  String get statusLabel {
    if (blockingCount > 0) return 'Dossier bloqué';
    if (warningCount > 0 || score < 85) return 'Dossier à finaliser';
    return 'Dossier prêt';
  }

  String buildShareSummary({
    required Vehicle vehicle,
    required SalePreparationProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('DOSSIER DE VENTE AUTOCLAIR')
      ..writeln('Véhicule : ${vehicle.displayName}')
      ..writeln('Kilométrage : ${vehicle.mileage ?? 0} km')
      ..writeln('Acheteur envisagé : ${profile.buyerType.label}')
      ..writeln('État du dossier : $statusLabel')
      ..writeln('Score de préparation : $score/100');
    if (profile.askingPrice > 0) {
      buffer.writeln(
        'Prix affiché : ${profile.askingPrice.toStringAsFixed(0)} €',
      );
      buffer.writeln(
        'Produit net estimé après préparation : '
        '${expectedNetAtAsking.toStringAsFixed(0)} €',
      );
    }
    buffer.writeln('Checklist :');
    for (final item in items) {
      buffer.writeln('- ${item.level.label} · ${item.title} : ${item.detail}');
    }
    buffer.writeln(
      'Ce document aide à préparer la vente. Il ne remplace pas les '
      'démarches officielles ni un conseil juridique.',
    );
    return buffer.toString().trim();
  }
}

class SalePreparationSnapshot {
  const SalePreparationSnapshot({
    required this.id,
    required this.score,
    required this.blockingCount,
    required this.warningCount,
    required this.expectedNetAtAsking,
    required this.createdAt,
  });

  final String id;
  final int score;
  final int blockingCount;
  final int warningCount;
  final double expectedNetAtAsking;
  final DateTime createdAt;

  factory SalePreparationSnapshot.fromMap(Map<String, dynamic> map) {
    return SalePreparationSnapshot(
      id: map['id']?.toString() ?? '',
      score: _integer(map['readiness_score']),
      blockingCount: _integer(map['blocking_count']),
      warningCount: _integer(map['warning_count']),
      expectedNetAtAsking: _decimal(map['expected_net_at_asking_eur']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

SaleBuyerType _buyerType(dynamic value) => switch (value?.toString()) {
  'AUTOMOTIVE_PROFESSIONAL' => SaleBuyerType.automotiveProfessional,
  _ => SaleBuyerType.privateIndividual,
};

SaleTechnicalControlStatus _technicalControlStatus(dynamic value) =>
    switch (value?.toString()) {
      'FAVORABLE' => SaleTechnicalControlStatus.favorable,
      'MAJOR_DEFECTS' => SaleTechnicalControlStatus.majorDefects,
      'CRITICAL_DEFECTS' => SaleTechnicalControlStatus.criticalDefects,
      'NOT_REQUIRED' => SaleTechnicalControlStatus.notRequired,
      _ => SaleTechnicalControlStatus.unknown,
    };

SaleCessionMethod _cessionMethod(dynamic value) => switch (value?.toString()) {
  'SIMPLIMMAT' => SaleCessionMethod.simplimmat,
  'FRANCE_TITRES' => SaleCessionMethod.franceTitres,
  _ => SaleCessionMethod.undecided,
};

int _integer(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _decimal(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}
