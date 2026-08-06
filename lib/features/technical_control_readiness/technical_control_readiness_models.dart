enum TechnicalControlVisitContext { periodic, counterVisit, sale, voluntary }

extension TechnicalControlVisitContextX on TechnicalControlVisitContext {
  String get databaseValue => switch (this) {
    TechnicalControlVisitContext.periodic => 'PERIODIC',
    TechnicalControlVisitContext.counterVisit => 'COUNTER_VISIT',
    TechnicalControlVisitContext.sale => 'SALE',
    TechnicalControlVisitContext.voluntary => 'VOLUNTARY',
  };

  String get label => switch (this) {
    TechnicalControlVisitContext.periodic => 'Visite périodique',
    TechnicalControlVisitContext.counterVisit => 'Contre-visite',
    TechnicalControlVisitContext.sale => 'Contrôle avant une vente',
    TechnicalControlVisitContext.voluntary => 'Contrôle volontaire',
  };
}

enum TechnicalControlCheckStatus {
  notChecked,
  satisfactory,
  attention,
  professionalCheck,
  blocking,
}

extension TechnicalControlCheckStatusX on TechnicalControlCheckStatus {
  String get databaseValue => switch (this) {
    TechnicalControlCheckStatus.notChecked => 'NOT_CHECKED',
    TechnicalControlCheckStatus.satisfactory => 'SATISFACTORY',
    TechnicalControlCheckStatus.attention => 'ATTENTION',
    TechnicalControlCheckStatus.professionalCheck => 'PROFESSIONAL_CHECK',
    TechnicalControlCheckStatus.blocking => 'BLOCKING',
  };

  String get label => switch (this) {
    TechnicalControlCheckStatus.notChecked => 'Non vérifié',
    TechnicalControlCheckStatus.satisfactory => 'Apparemment satisfaisant',
    TechnicalControlCheckStatus.attention => 'À corriger ou surveiller',
    TechnicalControlCheckStatus.professionalCheck => 'À faire vérifier',
    TechnicalControlCheckStatus.blocking => 'Problème manifeste',
  };
}

enum TechnicalControlReadinessLevel { ready, review, action, blocked }

extension TechnicalControlReadinessLevelX on TechnicalControlReadinessLevel {
  String get databaseValue => switch (this) {
    TechnicalControlReadinessLevel.ready => 'READY',
    TechnicalControlReadinessLevel.review => 'REVIEW',
    TechnicalControlReadinessLevel.action => 'ACTION',
    TechnicalControlReadinessLevel.blocked => 'BLOCKED',
  };

  String get label => switch (this) {
    TechnicalControlReadinessLevel.ready => 'Préparation cohérente',
    TechnicalControlReadinessLevel.review => 'Vérifications à terminer',
    TechnicalControlReadinessLevel.action => 'Actions recommandées',
    TechnicalControlReadinessLevel.blocked => 'Problème manifeste à traiter',
  };
}

enum TechnicalControlArea {
  registrationAndPlate,
  lightingAndSignals,
  tiresAndWheels,
  braking,
  steeringAndSuspension,
  visibility,
  bodyAndDoors,
  exhaustAndNoise,
  leaksAndFluids,
  warningLights,
  seatBeltsAndSeats,
  safetyEquipment,
}

extension TechnicalControlAreaX on TechnicalControlArea {
  String get databaseValue => switch (this) {
    TechnicalControlArea.registrationAndPlate => 'REGISTRATION_AND_PLATE',
    TechnicalControlArea.lightingAndSignals => 'LIGHTING_AND_SIGNALS',
    TechnicalControlArea.tiresAndWheels => 'TIRES_AND_WHEELS',
    TechnicalControlArea.braking => 'BRAKING',
    TechnicalControlArea.steeringAndSuspension => 'STEERING_AND_SUSPENSION',
    TechnicalControlArea.visibility => 'VISIBILITY',
    TechnicalControlArea.bodyAndDoors => 'BODY_AND_DOORS',
    TechnicalControlArea.exhaustAndNoise => 'EXHAUST_AND_NOISE',
    TechnicalControlArea.leaksAndFluids => 'LEAKS_AND_FLUIDS',
    TechnicalControlArea.warningLights => 'WARNING_LIGHTS',
    TechnicalControlArea.seatBeltsAndSeats => 'SEAT_BELTS_AND_SEATS',
    TechnicalControlArea.safetyEquipment => 'SAFETY_EQUIPMENT',
  };

  String get label => switch (this) {
    TechnicalControlArea.registrationAndPlate => 'Documents et plaques',
    TechnicalControlArea.lightingAndSignals => 'Éclairage et signalisation',
    TechnicalControlArea.tiresAndWheels => 'Pneus et roues',
    TechnicalControlArea.braking => 'Freinage',
    TechnicalControlArea.steeringAndSuspension => 'Direction et suspension',
    TechnicalControlArea.visibility => 'Visibilité et vitrages',
    TechnicalControlArea.bodyAndDoors => 'Carrosserie, ouvrants et fixation',
    TechnicalControlArea.exhaustAndNoise => 'Échappement et bruit anormal',
    TechnicalControlArea.leaksAndFluids => 'Fuites et niveaux visibles',
    TechnicalControlArea.warningLights => 'Voyants et démarrage',
    TechnicalControlArea.seatBeltsAndSeats => 'Ceintures et sièges',
    TechnicalControlArea.safetyEquipment => 'Équipements de sécurité',
  };

  bool get isSafetyCritical =>
      this == TechnicalControlArea.tiresAndWheels ||
      this == TechnicalControlArea.braking ||
      this == TechnicalControlArea.steeringAndSuspension ||
      this == TechnicalControlArea.visibility ||
      this == TechnicalControlArea.warningLights;
}

class TechnicalControlReadinessProfile {
  const TechnicalControlReadinessProfile({
    required this.vehicleId,
    required this.plannedDate,
    required this.visitContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.warningLightOn,
  });

  final String vehicleId;
  final DateTime plannedDate;
  final TechnicalControlVisitContext visitContext;
  final Map<TechnicalControlArea, TechnicalControlCheckStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool warningLightOn;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in TechnicalControlArea.values) {
      if (!checks.containsKey(area)) {
        throw FormatException('Le point « ${area.label} » est absent.');
      }
    }
    final reference = (now ?? DateTime.now()).toLocal();
    final selected = DateTime(
      plannedDate.year,
      plannedDate.month,
      plannedDate.day,
    );
    final today = DateTime(reference.year, reference.month, reference.day);
    if (selected.isBefore(today.subtract(const Duration(days: 1)))) {
      throw const FormatException('La date sélectionnée est déjà passée.');
    }
    if (selected.isAfter(today.add(const Duration(days: 366)))) {
      throw const FormatException('La date sélectionnée est trop éloignée.');
    }
  }

  Map<String, dynamic> toMap() => {
    'vehicle_id': vehicleId,
    'planned_date': _dateValue(plannedDate),
    'visit_context': visitContext.databaseValue,
    'vehicle_can_move_safely': vehicleCanMoveSafely,
    'warning_light_on': warningLightOn,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class TechnicalControlFinding {
  const TechnicalControlFinding({
    required this.code,
    required this.title,
    required this.action,
    required this.blocking,
  });

  final String code;
  final String title;
  final String action;
  final bool blocking;

  Map<String, dynamic> toMap() => {
    'code': code,
    'title': title,
    'action': action,
    'blocking': blocking,
  };
}

class TechnicalControlReadinessAssessment {
  const TechnicalControlReadinessAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.blockingCount,
    required this.findings,
  });

  final TechnicalControlReadinessLevel level;
  final int score;
  final int completenessPercent;
  final int blockingCount;
  final List<TechnicalControlFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required TechnicalControlReadinessProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — PRÉPARATION AU CONTRÔLE TECHNIQUE')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Contexte : ${profile.visitContext.label}')
      ..writeln('Date prévue : ${_formatDate(profile.plannedDate)}')
      ..writeln('État : ${level.label}')
      ..writeln('Indice de préparation : $score/100')
      ..writeln('Points vérifiés : $completenessPercent %')
      ..writeln('Problèmes manifestes déclarés : $blockingCount');
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
        'Cette préparation porte uniquement sur les informations déclarées et '
        'les vérifications visibles. Elle ne garantit pas le résultat du '
        'contrôle et ne remplace pas le centre agréé ou un professionnel.',
      );
    return buffer.toString().trim();
  }
}

class TechnicalControlReadinessSnapshot {
  const TechnicalControlReadinessSnapshot({
    required this.id,
    required this.plannedDate,
    required this.visitContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime plannedDate;
  final TechnicalControlVisitContext visitContext;
  final TechnicalControlReadinessLevel level;
  final int score;
  final int completenessPercent;

  factory TechnicalControlReadinessSnapshot.fromMap(Map<String, dynamic> map) {
    return TechnicalControlReadinessSnapshot(
      id: map['id']?.toString() ?? '',
      plannedDate: DateTime.parse(map['planned_date'].toString()),
      visitContext: technicalControlVisitContextFromDatabase(
        map['visit_context']?.toString(),
      ),
      level: technicalControlReadinessLevelFromDatabase(
        map['readiness_level']?.toString(),
      ),
      score: (map['readiness_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

TechnicalControlVisitContext technicalControlVisitContextFromDatabase(
  String? value,
) => switch (value) {
  'COUNTER_VISIT' => TechnicalControlVisitContext.counterVisit,
  'SALE' => TechnicalControlVisitContext.sale,
  'VOLUNTARY' => TechnicalControlVisitContext.voluntary,
  _ => TechnicalControlVisitContext.periodic,
};

TechnicalControlReadinessLevel technicalControlReadinessLevelFromDatabase(
  String? value,
) => switch (value) {
  'REVIEW' => TechnicalControlReadinessLevel.review,
  'ACTION' => TechnicalControlReadinessLevel.action,
  'BLOCKED' => TechnicalControlReadinessLevel.blocked,
  _ => TechnicalControlReadinessLevel.ready,
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
