import 'dart:math' as math;

enum PurchaseSellerType { privateIndividual, automotiveProfessional }

extension PurchaseSellerTypeX on PurchaseSellerType {
  String get databaseValue => switch (this) {
    PurchaseSellerType.privateIndividual => 'PRIVATE_INDIVIDUAL',
    PurchaseSellerType.automotiveProfessional => 'AUTOMOTIVE_PROFESSIONAL',
  };

  String get label => switch (this) {
    PurchaseSellerType.privateIndividual => 'Particulier',
    PurchaseSellerType.automotiveProfessional => 'Professionnel automobile',
  };
}

enum PurchaseTechnicalControlStatus {
  unknown,
  favorable,
  majorDefects,
  criticalDefects,
  notRequired,
}

extension PurchaseTechnicalControlStatusX on PurchaseTechnicalControlStatus {
  String get databaseValue => switch (this) {
    PurchaseTechnicalControlStatus.unknown => 'UNKNOWN',
    PurchaseTechnicalControlStatus.favorable => 'FAVORABLE',
    PurchaseTechnicalControlStatus.majorDefects => 'MAJOR_DEFECTS',
    PurchaseTechnicalControlStatus.criticalDefects => 'CRITICAL_DEFECTS',
    PurchaseTechnicalControlStatus.notRequired => 'NOT_REQUIRED',
  };

  String get label => switch (this) {
    PurchaseTechnicalControlStatus.unknown => 'À vérifier',
    PurchaseTechnicalControlStatus.favorable => 'Favorable',
    PurchaseTechnicalControlStatus.majorDefects =>
      'Défaillances majeures / contre-visite',
    PurchaseTechnicalControlStatus.criticalDefects => 'Défaillance critique',
    PurchaseTechnicalControlStatus.notRequired => 'Non requis',
  };
}

enum PurchaseCheckLevel { ready, warning, blocking, optional }

extension PurchaseCheckLevelX on PurchaseCheckLevel {
  String get label => switch (this) {
    PurchaseCheckLevel.ready => 'Validé',
    PurchaseCheckLevel.warning => 'À vérifier',
    PurchaseCheckLevel.blocking => 'Stop',
    PurchaseCheckLevel.optional => 'Recommandé',
  };
}

enum PurchaseDecisionLevel { ready, caution, stop }

extension PurchaseDecisionLevelX on PurchaseDecisionLevel {
  String get databaseValue => switch (this) {
    PurchaseDecisionLevel.ready => 'READY',
    PurchaseDecisionLevel.caution => 'CAUTION',
    PurchaseDecisionLevel.stop => 'STOP',
  };

  String get label => switch (this) {
    PurchaseDecisionLevel.ready => 'Dossier solide',
    PurchaseDecisionLevel.caution => 'Points à clarifier',
    PurchaseDecisionLevel.stop => 'Ne pas s’engager',
  };
}

class UsedPurchaseProfile {
  const UsedPurchaseProfile({
    required this.sellerType,
    required this.make,
    required this.model,
    required this.vehicleYear,
    required this.mileage,
    required this.askingPrice,
    required this.registrationCost,
    required this.immediateRepairBudget,
    required this.inspectionCost,
    required this.availableBudget,
    required this.sellerRightToSellVerified,
    required this.registrationAvailable,
    required this.vinMatchesRegistration,
    required this.csaClear,
    required this.histovecReviewed,
    required this.technicalControlStatus,
    required this.mileageHistoryCoherent,
    required this.maintenanceEvidence,
    required this.coldStartObserved,
    required this.warningLightsClear,
    required this.testDriveCompleted,
    required this.brakingSteeringHealthy,
    required this.leaksOrSmokeDetected,
    required this.bodyStructureConcern,
    required this.securePaymentPlanned,
    required this.depositBeforeChecks,
    this.csaIssuedAt,
    this.technicalControlDate,
  });

  final PurchaseSellerType sellerType;
  final String make;
  final String model;
  final int? vehicleYear;
  final int? mileage;
  final double askingPrice;
  final double registrationCost;
  final double immediateRepairBudget;
  final double inspectionCost;
  final double availableBudget;
  final bool sellerRightToSellVerified;
  final bool registrationAvailable;
  final bool vinMatchesRegistration;
  final DateTime? csaIssuedAt;
  final bool csaClear;
  final bool histovecReviewed;
  final DateTime? technicalControlDate;
  final PurchaseTechnicalControlStatus technicalControlStatus;
  final bool mileageHistoryCoherent;
  final bool maintenanceEvidence;
  final bool coldStartObserved;
  final bool warningLightsClear;
  final bool testDriveCompleted;
  final bool brakingSteeringHealthy;
  final bool leaksOrSmokeDetected;
  final bool bodyStructureConcern;
  final bool securePaymentPlanned;
  final bool depositBeforeChecks;

  factory UsedPurchaseProfile.defaults() {
    return const UsedPurchaseProfile(
      sellerType: PurchaseSellerType.privateIndividual,
      make: '',
      model: '',
      vehicleYear: null,
      mileage: null,
      askingPrice: 0,
      registrationCost: 0,
      immediateRepairBudget: 0,
      inspectionCost: 0,
      availableBudget: 0,
      sellerRightToSellVerified: false,
      registrationAvailable: false,
      vinMatchesRegistration: false,
      csaClear: false,
      histovecReviewed: false,
      technicalControlStatus: PurchaseTechnicalControlStatus.unknown,
      mileageHistoryCoherent: false,
      maintenanceEvidence: false,
      coldStartObserved: false,
      warningLightsClear: false,
      testDriveCompleted: false,
      brakingSteeringHealthy: false,
      leaksOrSmokeDetected: false,
      bodyStructureConcern: false,
      securePaymentPlanned: false,
      depositBeforeChecks: false,
    );
  }

  factory UsedPurchaseProfile.fromMap(Map<String, dynamic> map) {
    return UsedPurchaseProfile(
      sellerType: _sellerType(map['seller_type']),
      make: map['make']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      vehicleYear: _nullableInteger(map['vehicle_year']),
      mileage: _nullableInteger(map['mileage']),
      askingPrice: _decimal(map['asking_price_eur']),
      registrationCost: _decimal(map['registration_cost_eur']),
      immediateRepairBudget: _decimal(map['immediate_repairs_eur']),
      inspectionCost: _decimal(map['inspection_cost_eur']),
      availableBudget: _decimal(map['available_budget_eur']),
      sellerRightToSellVerified:
          map['seller_right_to_sell_verified'] as bool? ?? false,
      registrationAvailable: map['registration_available'] as bool? ?? false,
      vinMatchesRegistration: map['vin_matches_registration'] as bool? ?? false,
      csaIssuedAt: _date(map['csa_issued_at']),
      csaClear: map['csa_clear'] as bool? ?? false,
      histovecReviewed: map['histovec_reviewed'] as bool? ?? false,
      technicalControlDate: _date(map['technical_control_date']),
      technicalControlStatus: _technicalControlStatus(
        map['technical_control_status'],
      ),
      mileageHistoryCoherent: map['mileage_history_coherent'] as bool? ?? false,
      maintenanceEvidence: map['maintenance_evidence'] as bool? ?? false,
      coldStartObserved: map['cold_start_observed'] as bool? ?? false,
      warningLightsClear: map['warning_lights_clear'] as bool? ?? false,
      testDriveCompleted: map['test_drive_completed'] as bool? ?? false,
      brakingSteeringHealthy: map['braking_steering_healthy'] as bool? ?? false,
      leaksOrSmokeDetected: map['leaks_or_smoke_detected'] as bool? ?? false,
      bodyStructureConcern: map['body_structure_concern'] as bool? ?? false,
      securePaymentPlanned: map['secure_payment_planned'] as bool? ?? false,
      depositBeforeChecks: map['deposit_before_checks'] as bool? ?? false,
    );
  }

  void validate() {
    if (make.trim().length > 80 || model.trim().length > 80) {
      throw const FormatException(
        'La marque et le modèle sont limités à 80 caractères.',
      );
    }
    final year = vehicleYear;
    if (year != null && (year < 1900 || year > 2100)) {
      throw const FormatException("L’année du véhicule est invalide.");
    }
    final currentMileage = mileage;
    if (currentMileage != null &&
        (currentMileage < 0 || currentMileage > 3000000)) {
      throw const FormatException('Le kilométrage est invalide.');
    }
    for (final amount in [
      askingPrice,
      registrationCost,
      immediateRepairBudget,
      inspectionCost,
      availableBudget,
    ]) {
      if (!amount.isFinite || amount < 0 || amount > 2000000) {
        throw const FormatException('Un montant saisi est invalide.');
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'seller_type': sellerType.databaseValue,
      'make': _nullIfEmpty(make),
      'model': _nullIfEmpty(model),
      'vehicle_year': vehicleYear,
      'mileage': mileage,
      'asking_price_eur': askingPrice,
      'registration_cost_eur': registrationCost,
      'immediate_repairs_eur': immediateRepairBudget,
      'inspection_cost_eur': inspectionCost,
      'available_budget_eur': availableBudget,
      'seller_right_to_sell_verified': sellerRightToSellVerified,
      'registration_available': registrationAvailable,
      'vin_matches_registration': vinMatchesRegistration,
      'csa_issued_at': _dateValue(csaIssuedAt),
      'csa_clear': csaClear,
      'histovec_reviewed': histovecReviewed,
      'technical_control_date': _dateValue(technicalControlDate),
      'technical_control_status': technicalControlStatus.databaseValue,
      'mileage_history_coherent': mileageHistoryCoherent,
      'maintenance_evidence': maintenanceEvidence,
      'cold_start_observed': coldStartObserved,
      'warning_lights_clear': warningLightsClear,
      'test_drive_completed': testDriveCompleted,
      'braking_steering_healthy': brakingSteeringHealthy,
      'leaks_or_smoke_detected': leaksOrSmokeDetected,
      'body_structure_concern': bodyStructureConcern,
      'secure_payment_planned': securePaymentPlanned,
      'deposit_before_checks': depositBeforeChecks,
    };
  }
}

class PurchaseChecklistItem {
  const PurchaseChecklistItem({
    required this.code,
    required this.title,
    required this.detail,
    required this.level,
  });

  final String code;
  final String title;
  final String detail;
  final PurchaseCheckLevel level;

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'title': title,
      'detail': detail,
      'level': level.name.toUpperCase(),
    };
  }
}

class UsedPurchaseAssessment {
  const UsedPurchaseAssessment({
    required this.score,
    required this.decisionLevel,
    required this.blockingCount,
    required this.warningCount,
    required this.totalAcquisitionCost,
    required this.remainingBudget,
    required this.items,
    required this.technicalControlRequired,
    this.csaExpiresAt,
    this.technicalControlExpiresAt,
  });

  final int score;
  final PurchaseDecisionLevel decisionLevel;
  final int blockingCount;
  final int warningCount;
  final double totalAcquisitionCost;
  final double remainingBudget;
  final List<PurchaseChecklistItem> items;
  final bool technicalControlRequired;
  final DateTime? csaExpiresAt;
  final DateTime? technicalControlExpiresAt;

  String buildShareSummary(UsedPurchaseProfile profile) {
    final vehicleLabel = [
      profile.make.trim(),
      profile.model.trim(),
      if (profile.vehicleYear != null) profile.vehicleYear.toString(),
    ].where((value) => value.isNotEmpty).join(' ');
    final buffer = StringBuffer()
      ..writeln('AutoClair — Vérification avant achat')
      ..writeln(vehicleLabel.isEmpty ? 'Véhicule à préciser' : vehicleLabel)
      ..writeln('Décision : ${decisionLevel.label}')
      ..writeln('Score : $score/100')
      ..writeln('Coût total estimé : ${_money(totalAcquisitionCost)}')
      ..writeln('Marge sur budget : ${_money(remainingBudget)}')
      ..writeln('Points bloquants : $blockingCount')
      ..writeln('Points à vérifier : $warningCount');

    for (final item in items.where(
      (item) => item.level != PurchaseCheckLevel.ready,
    )) {
      buffer.writeln('- ${item.title} : ${item.detail}');
    }
    buffer.writeln(
      'Ce bilan est une aide à la décision, pas une expertise mécanique.',
    );
    return buffer.toString().trim();
  }
}

class UsedPurchaseSnapshot {
  const UsedPurchaseSnapshot({
    required this.id,
    required this.createdAt,
    required this.make,
    required this.model,
    required this.score,
    required this.decisionLevel,
    required this.totalAcquisitionCost,
  });

  final String id;
  final DateTime createdAt;
  final String make;
  final String model;
  final int score;
  final PurchaseDecisionLevel decisionLevel;
  final double totalAcquisitionCost;

  factory UsedPurchaseSnapshot.fromMap(Map<String, dynamic> map) {
    return UsedPurchaseSnapshot(
      id: map['id']?.toString() ?? '',
      createdAt: DateTime.parse(map['created_at'].toString()).toLocal(),
      make: map['make']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      score: _integer(map['readiness_score']),
      decisionLevel: _decisionLevel(map['decision_level']),
      totalAcquisitionCost: _decimal(map['total_acquisition_cost_eur']),
    );
  }
}

PurchaseSellerType _sellerType(Object? raw) {
  return switch (raw?.toString().toUpperCase()) {
    'AUTOMOTIVE_PROFESSIONAL' => PurchaseSellerType.automotiveProfessional,
    _ => PurchaseSellerType.privateIndividual,
  };
}

PurchaseTechnicalControlStatus _technicalControlStatus(Object? raw) {
  return switch (raw?.toString().toUpperCase()) {
    'FAVORABLE' => PurchaseTechnicalControlStatus.favorable,
    'MAJOR_DEFECTS' => PurchaseTechnicalControlStatus.majorDefects,
    'CRITICAL_DEFECTS' => PurchaseTechnicalControlStatus.criticalDefects,
    'NOT_REQUIRED' => PurchaseTechnicalControlStatus.notRequired,
    _ => PurchaseTechnicalControlStatus.unknown,
  };
}

PurchaseDecisionLevel _decisionLevel(Object? raw) {
  return switch (raw?.toString().toUpperCase()) {
    'READY' => PurchaseDecisionLevel.ready,
    'STOP' => PurchaseDecisionLevel.stop,
    _ => PurchaseDecisionLevel.caution,
  };
}

DateTime? _date(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

String? _dateValue(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _integer(Object? raw) {
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

int? _nullableInteger(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

double _decimal(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

String _money(double value) {
  final normalized = value.abs() < 0.005 ? 0.0 : value;
  return '${normalized.toStringAsFixed(2)} €';
}

int clampScore(int value) => math.max(0, math.min(100, value));
