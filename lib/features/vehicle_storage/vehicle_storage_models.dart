enum VehicleStorageScenario { shortPause, winterStorage, longStorage, restart }

extension VehicleStorageScenarioX on VehicleStorageScenario {
  String get databaseValue => switch (this) {
    VehicleStorageScenario.shortPause => 'SHORT_PAUSE',
    VehicleStorageScenario.winterStorage => 'WINTER_STORAGE',
    VehicleStorageScenario.longStorage => 'LONG_STORAGE',
    VehicleStorageScenario.restart => 'RESTART',
  };

  String get label => switch (this) {
    VehicleStorageScenario.shortPause => 'Pause de quelques semaines',
    VehicleStorageScenario.winterStorage => 'Hivernage',
    VehicleStorageScenario.longStorage => 'Immobilisation prolongée',
    VehicleStorageScenario.restart => 'Remise en route',
  };
}

enum VehicleStorageStatus {
  notChecked,
  notApplicable,
  ready,
  attention,
  blocking,
}

extension VehicleStorageStatusX on VehicleStorageStatus {
  String get databaseValue => switch (this) {
    VehicleStorageStatus.notChecked => 'NOT_CHECKED',
    VehicleStorageStatus.notApplicable => 'NOT_APPLICABLE',
    VehicleStorageStatus.ready => 'READY',
    VehicleStorageStatus.attention => 'ATTENTION',
    VehicleStorageStatus.blocking => 'BLOCKING',
  };

  String get label => switch (this) {
    VehicleStorageStatus.notChecked => 'Non vérifié',
    VehicleStorageStatus.notApplicable => 'Non concerné',
    VehicleStorageStatus.ready => 'Préparé',
    VehicleStorageStatus.attention => 'À vérifier',
    VehicleStorageStatus.blocking => 'À corriger avant de poursuivre',
  };
}

enum VehicleStorageLevel { ready, review, action, blocked }

extension VehicleStorageLevelX on VehicleStorageLevel {
  String get databaseValue => switch (this) {
    VehicleStorageLevel.ready => 'READY',
    VehicleStorageLevel.review => 'REVIEW',
    VehicleStorageLevel.action => 'ACTION',
    VehicleStorageLevel.blocked => 'BLOCKED',
  };

  String get label => switch (this) {
    VehicleStorageLevel.ready => 'Préparation cohérente',
    VehicleStorageLevel.review => 'Vérifications à terminer',
    VehicleStorageLevel.action => 'Actions recommandées',
    VehicleStorageLevel.blocked => 'Action prioritaire avant de poursuivre',
  };
}

enum VehicleStorageArea {
  cleanAndDry,
  tires,
  twelveVoltBattery,
  tractionBattery,
  fuelOrCharge,
  fluidsAndLeaks,
  parkingAndBrakes,
  ventilationAndProtection,
  insuranceAndDocuments,
  keysAndSecurity,
  restartPlan,
}

extension VehicleStorageAreaX on VehicleStorageArea {
  String get databaseValue => switch (this) {
    VehicleStorageArea.cleanAndDry => 'CLEAN_AND_DRY',
    VehicleStorageArea.tires => 'TIRES',
    VehicleStorageArea.twelveVoltBattery => 'TWELVE_VOLT_BATTERY',
    VehicleStorageArea.tractionBattery => 'TRACTION_BATTERY',
    VehicleStorageArea.fuelOrCharge => 'FUEL_OR_CHARGE',
    VehicleStorageArea.fluidsAndLeaks => 'FLUIDS_AND_LEAKS',
    VehicleStorageArea.parkingAndBrakes => 'PARKING_AND_BRAKES',
    VehicleStorageArea.ventilationAndProtection => 'VENTILATION_AND_PROTECTION',
    VehicleStorageArea.insuranceAndDocuments => 'INSURANCE_AND_DOCUMENTS',
    VehicleStorageArea.keysAndSecurity => 'KEYS_AND_SECURITY',
    VehicleStorageArea.restartPlan => 'RESTART_PLAN',
  };

  String get label => switch (this) {
    VehicleStorageArea.cleanAndDry => 'Véhicule propre et sec',
    VehicleStorageArea.tires => 'Pneus et appuis prolongés',
    VehicleStorageArea.twelveVoltBattery => 'Batterie 12 V',
    VehicleStorageArea.tractionBattery => 'Batterie de traction',
    VehicleStorageArea.fuelOrCharge => 'Carburant ou niveau de charge',
    VehicleStorageArea.fluidsAndLeaks => 'Niveaux et absence de fuite',
    VehicleStorageArea.parkingAndBrakes => 'Stationnement et freinage',
    VehicleStorageArea.ventilationAndProtection => 'Ventilation et protection',
    VehicleStorageArea.insuranceAndDocuments => 'Assurance et documents',
    VehicleStorageArea.keysAndSecurity => 'Clés et sécurité',
    VehicleStorageArea.restartPlan => 'Plan de remise en route',
  };

  bool get isSafetyCritical =>
      this == VehicleStorageArea.tires ||
      this == VehicleStorageArea.fluidsAndLeaks ||
      this == VehicleStorageArea.parkingAndBrakes;
}

class VehicleStorageProfile {
  const VehicleStorageProfile({
    required this.vehicleId,
    required this.plannedStartDate,
    required this.plannedWeeks,
    required this.scenario,
    required this.checks,
    required this.electricOrHybrid,
    required this.outdoorStorage,
    required this.humidEnvironment,
  });

  final String vehicleId;
  final DateTime plannedStartDate;
  final int plannedWeeks;
  final VehicleStorageScenario scenario;
  final Map<VehicleStorageArea, VehicleStorageStatus> checks;
  final bool electricOrHybrid;
  final bool outdoorStorage;
  final bool humidEnvironment;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    if (plannedWeeks < 1 || plannedWeeks > 104) {
      throw const FormatException(
        'La durée doit rester comprise entre 1 et 104 semaines.',
      );
    }
    for (final area in VehicleStorageArea.values) {
      if (!checks.containsKey(area)) {
        throw FormatException('Le point « ${area.label} » est absent.');
      }
      final value = checks[area]!;
      if (area != VehicleStorageArea.tractionBattery &&
          value == VehicleStorageStatus.notApplicable) {
        throw FormatException(
          'Le point « ${area.label} » ne peut pas être ignoré.',
        );
      }
    }
    final tractionStatus = checks[VehicleStorageArea.tractionBattery]!;
    if (electricOrHybrid &&
        tractionStatus == VehicleStorageStatus.notApplicable) {
      throw const FormatException(
        'La batterie de traction doit être vérifiée.',
      );
    }
    if (!electricOrHybrid &&
        tractionStatus != VehicleStorageStatus.notApplicable) {
      throw const FormatException(
        'Indiquez « Non concerné » pour la batterie de traction.',
      );
    }
    final reference = (now ?? DateTime.now()).toLocal();
    final selected = DateTime(
      plannedStartDate.year,
      plannedStartDate.month,
      plannedStartDate.day,
    );
    final today = DateTime(reference.year, reference.month, reference.day);
    if (selected.isBefore(today.subtract(const Duration(days: 1)))) {
      throw const FormatException('La date sélectionnée est déjà passée.');
    }
    if (selected.isAfter(today.add(const Duration(days: 366)))) {
      throw const FormatException('La date sélectionnée est trop éloignée.');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'planned_start_date': _dateValue(plannedStartDate),
      'planned_weeks': plannedWeeks,
      'scenario': scenario.databaseValue,
      'electric_or_hybrid': electricOrHybrid,
      'outdoor_storage': outdoorStorage,
      'humid_environment': humidEnvironment,
      'checks': {
        for (final entry in checks.entries)
          entry.key.databaseValue: entry.value.databaseValue,
      },
    };
  }
}

class VehicleStorageFinding {
  const VehicleStorageFinding({
    required this.code,
    required this.title,
    required this.detail,
    required this.action,
    required this.blocking,
  });

  final String code;
  final String title;
  final String detail;
  final String action;
  final bool blocking;

  Map<String, dynamic> toMap() => {
    'code': code,
    'title': title,
    'detail': detail,
    'action': action,
    'blocking': blocking,
  };
}

class VehicleStorageAssessment {
  const VehicleStorageAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.blockingCount,
    required this.findings,
  });

  final VehicleStorageLevel level;
  final int score;
  final int completenessPercent;
  final int blockingCount;
  final List<VehicleStorageFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required VehicleStorageProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — IMMOBILISATION ET REMISE EN ROUTE')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Contexte : ${profile.scenario.label}')
      ..writeln('Date prévue : ${_formatDate(profile.plannedStartDate)}')
      ..writeln('Durée indicative : ${profile.plannedWeeks} semaine(s)')
      ..writeln('État : ${level.label}')
      ..writeln('Indice : $score/100')
      ..writeln('Points vérifiés : $completenessPercent %')
      ..writeln('Points bloquants déclarés : $blockingCount');
    if (findings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Actions principales :');
      for (final finding in findings.take(6)) {
        buffer.writeln('- ${finding.title} : ${finding.action}');
      }
    }
    buffer
      ..writeln()
      ..writeln(
        'AutoClair n’enregistre aucun lieu de stockage. Cette checklist ne '
        'remplace pas le manuel constructeur, les conditions du contrat '
        'd’assurance ou le contrôle d’un professionnel.',
      );
    return buffer.toString().trim();
  }
}

class VehicleStorageSnapshot {
  const VehicleStorageSnapshot({
    required this.id,
    required this.plannedStartDate,
    required this.plannedWeeks,
    required this.scenario,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime plannedStartDate;
  final int plannedWeeks;
  final VehicleStorageScenario scenario;
  final VehicleStorageLevel level;
  final int score;
  final int completenessPercent;

  factory VehicleStorageSnapshot.fromMap(Map<String, dynamic> map) {
    return VehicleStorageSnapshot(
      id: map['id']?.toString() ?? '',
      plannedStartDate: DateTime.parse(map['planned_start_date'].toString()),
      plannedWeeks: (map['planned_weeks'] as num?)?.toInt() ?? 1,
      scenario: vehicleStorageScenarioFromDatabase(map['scenario']?.toString()),
      level: vehicleStorageLevelFromDatabase(
        map['readiness_level']?.toString(),
      ),
      score: (map['readiness_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

VehicleStorageScenario vehicleStorageScenarioFromDatabase(String? value) =>
    switch (value) {
      'WINTER_STORAGE' => VehicleStorageScenario.winterStorage,
      'LONG_STORAGE' => VehicleStorageScenario.longStorage,
      'RESTART' => VehicleStorageScenario.restart,
      _ => VehicleStorageScenario.shortPause,
    };

VehicleStorageLevel vehicleStorageLevelFromDatabase(String? value) =>
    switch (value) {
      'REVIEW' => VehicleStorageLevel.review,
      'ACTION' => VehicleStorageLevel.action,
      'BLOCKED' => VehicleStorageLevel.blocked,
      _ => VehicleStorageLevel.ready,
    };

String _dateValue(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
