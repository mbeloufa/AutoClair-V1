enum WorkshopVisitReason {
  routineMaintenance,
  warningLight,
  noiseOrVibration,
  leakOrOdor,
  brakingOrSteering,
  electricalOrClimate,
  bodywork,
  recallOrCampaign,
}

extension WorkshopVisitReasonX on WorkshopVisitReason {
  String get databaseValue => switch (this) {
    WorkshopVisitReason.routineMaintenance => 'ROUTINE_MAINTENANCE',
    WorkshopVisitReason.warningLight => 'WARNING_LIGHT',
    WorkshopVisitReason.noiseOrVibration => 'NOISE_OR_VIBRATION',
    WorkshopVisitReason.leakOrOdor => 'LEAK_OR_ODOR',
    WorkshopVisitReason.brakingOrSteering => 'BRAKING_OR_STEERING',
    WorkshopVisitReason.electricalOrClimate => 'ELECTRICAL_OR_CLIMATE',
    WorkshopVisitReason.bodywork => 'BODYWORK',
    WorkshopVisitReason.recallOrCampaign => 'RECALL_OR_CAMPAIGN',
  };

  String get label => switch (this) {
    WorkshopVisitReason.routineMaintenance => 'Entretien courant',
    WorkshopVisitReason.warningLight => 'Voyant allumé',
    WorkshopVisitReason.noiseOrVibration => 'Bruit ou vibration',
    WorkshopVisitReason.leakOrOdor => 'Fuite ou odeur inhabituelle',
    WorkshopVisitReason.brakingOrSteering => 'Freinage ou direction',
    WorkshopVisitReason.electricalOrClimate => 'Électricité ou climatisation',
    WorkshopVisitReason.bodywork => 'Carrosserie ou vitrage',
    WorkshopVisitReason.recallOrCampaign => 'Rappel ou campagne constructeur',
  };
}

enum WorkshopPreparationStatus {
  notChecked,
  ready,
  toPrepare,
  discussWithProfessional,
  urgent,
}

extension WorkshopPreparationStatusX on WorkshopPreparationStatus {
  String get databaseValue => switch (this) {
    WorkshopPreparationStatus.notChecked => 'NOT_CHECKED',
    WorkshopPreparationStatus.ready => 'READY',
    WorkshopPreparationStatus.toPrepare => 'TO_PREPARE',
    WorkshopPreparationStatus.discussWithProfessional => 'DISCUSS',
    WorkshopPreparationStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    WorkshopPreparationStatus.notChecked => 'Non vérifié',
    WorkshopPreparationStatus.ready => 'Prêt',
    WorkshopPreparationStatus.toPrepare => 'À préparer',
    WorkshopPreparationStatus.discussWithProfessional =>
      'À clarifier au garage',
    WorkshopPreparationStatus.urgent => 'Prioritaire avant de circuler',
  };
}

enum WorkshopPreparationLevel { ready, review, action, urgent }

extension WorkshopPreparationLevelX on WorkshopPreparationLevel {
  String get databaseValue => switch (this) {
    WorkshopPreparationLevel.ready => 'READY',
    WorkshopPreparationLevel.review => 'REVIEW',
    WorkshopPreparationLevel.action => 'ACTION',
    WorkshopPreparationLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    WorkshopPreparationLevel.ready => 'Dossier prêt',
    WorkshopPreparationLevel.review => 'Préparation à terminer',
    WorkshopPreparationLevel.action => 'Actions recommandées',
    WorkshopPreparationLevel.urgent => 'Avis professionnel prioritaire',
  };
}

enum WorkshopPreparationArea {
  vehicleInformation,
  currentMileage,
  symptomConditions,
  warningLights,
  recentWork,
  documents,
  estimateRequest,
  authorizationLimit,
  oldPartsPreference,
  mobilityNeeds,
  keysAndAccess,
  drivingSafety,
}

extension WorkshopPreparationAreaX on WorkshopPreparationArea {
  String get databaseValue => switch (this) {
    WorkshopPreparationArea.vehicleInformation => 'VEHICLE_INFORMATION',
    WorkshopPreparationArea.currentMileage => 'CURRENT_MILEAGE',
    WorkshopPreparationArea.symptomConditions => 'SYMPTOM_CONDITIONS',
    WorkshopPreparationArea.warningLights => 'WARNING_LIGHTS',
    WorkshopPreparationArea.recentWork => 'RECENT_WORK',
    WorkshopPreparationArea.documents => 'DOCUMENTS',
    WorkshopPreparationArea.estimateRequest => 'ESTIMATE_REQUEST',
    WorkshopPreparationArea.authorizationLimit => 'AUTHORIZATION_LIMIT',
    WorkshopPreparationArea.oldPartsPreference => 'OLD_PARTS_PREFERENCE',
    WorkshopPreparationArea.mobilityNeeds => 'MOBILITY_NEEDS',
    WorkshopPreparationArea.keysAndAccess => 'KEYS_AND_ACCESS',
    WorkshopPreparationArea.drivingSafety => 'DRIVING_SAFETY',
  };

  String get label => switch (this) {
    WorkshopPreparationArea.vehicleInformation => 'Informations du véhicule',
    WorkshopPreparationArea.currentMileage => 'Kilométrage actuel',
    WorkshopPreparationArea.symptomConditions => 'Circonstances du symptôme',
    WorkshopPreparationArea.warningLights => 'Voyants observés',
    WorkshopPreparationArea.recentWork => 'Interventions récentes',
    WorkshopPreparationArea.documents => 'Factures et documents utiles',
    WorkshopPreparationArea.estimateRequest => 'Demande de devis',
    WorkshopPreparationArea.authorizationLimit =>
      'Travaux à autoriser avant accord',
    WorkshopPreparationArea.oldPartsPreference => 'Sort des pièces remplacées',
    WorkshopPreparationArea.mobilityNeeds => 'Besoin de mobilité',
    WorkshopPreparationArea.keysAndAccess => 'Clés et accès au véhicule',
    WorkshopPreparationArea.drivingSafety => 'Sécurité avant déplacement',
  };

  bool get isSafetyCritical =>
      this == WorkshopPreparationArea.warningLights ||
      this == WorkshopPreparationArea.drivingSafety;
}

class WorkshopVisitPreparationProfile {
  const WorkshopVisitPreparationProfile({
    required this.vehicleId,
    required this.plannedDate,
    required this.visitReason,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.warningLightOn,
  });

  final String vehicleId;
  final DateTime plannedDate;
  final WorkshopVisitReason visitReason;
  final Map<WorkshopPreparationArea, WorkshopPreparationStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool warningLightOn;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in WorkshopPreparationArea.values) {
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
    'visit_reason': visitReason.databaseValue,
    'vehicle_can_move_safely': vehicleCanMoveSafely,
    'warning_light_on': warningLightOn,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class WorkshopPreparationFinding {
  const WorkshopPreparationFinding({
    required this.code,
    required this.title,
    required this.action,
    required this.urgent,
  });

  final String code;
  final String title;
  final String action;
  final bool urgent;

  Map<String, dynamic> toMap() => {
    'code': code,
    'title': title,
    'action': action,
    'urgent': urgent,
  };
}

class WorkshopVisitPreparationAssessment {
  const WorkshopVisitPreparationAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final WorkshopPreparationLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<WorkshopPreparationFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required WorkshopVisitPreparationProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — PRÉPARATION DE VISITE AU GARAGE')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Motif : ${profile.visitReason.label}')
      ..writeln('Date prévue : ${_formatDate(profile.plannedDate)}')
      ..writeln('État : ${level.label}')
      ..writeln('Indice de préparation : $score/100')
      ..writeln('Points préparés : $completenessPercent %')
      ..writeln('Points urgents déclarés : $urgentCount');
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
        'Ce résumé organise uniquement les informations déclarées. Il ne pose '
        'pas de diagnostic, ne remplace pas un professionnel et ne vaut ni devis '
        'ni autorisation de travaux.',
      );
    return buffer.toString().trim();
  }
}

class WorkshopVisitPreparationSnapshot {
  const WorkshopVisitPreparationSnapshot({
    required this.id,
    required this.plannedDate,
    required this.visitReason,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime plannedDate;
  final WorkshopVisitReason visitReason;
  final WorkshopPreparationLevel level;
  final int score;
  final int completenessPercent;

  factory WorkshopVisitPreparationSnapshot.fromMap(Map<String, dynamic> map) {
    return WorkshopVisitPreparationSnapshot(
      id: map['id']?.toString() ?? '',
      plannedDate: DateTime.parse(map['planned_date'].toString()),
      visitReason: workshopVisitReasonFromDatabase(
        map['visit_reason']?.toString(),
      ),
      level: workshopPreparationLevelFromDatabase(
        map['preparation_level']?.toString(),
      ),
      score: (map['preparation_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

WorkshopVisitReason workshopVisitReasonFromDatabase(String? value) =>
    switch (value) {
      'WARNING_LIGHT' => WorkshopVisitReason.warningLight,
      'NOISE_OR_VIBRATION' => WorkshopVisitReason.noiseOrVibration,
      'LEAK_OR_ODOR' => WorkshopVisitReason.leakOrOdor,
      'BRAKING_OR_STEERING' => WorkshopVisitReason.brakingOrSteering,
      'ELECTRICAL_OR_CLIMATE' => WorkshopVisitReason.electricalOrClimate,
      'BODYWORK' => WorkshopVisitReason.bodywork,
      'RECALL_OR_CAMPAIGN' => WorkshopVisitReason.recallOrCampaign,
      _ => WorkshopVisitReason.routineMaintenance,
    };

WorkshopPreparationLevel workshopPreparationLevelFromDatabase(String? value) =>
    switch (value) {
      'REVIEW' => WorkshopPreparationLevel.review,
      'ACTION' => WorkshopPreparationLevel.action,
      'URGENT' => WorkshopPreparationLevel.urgent,
      _ => WorkshopPreparationLevel.ready,
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
