enum FluidCheckContext {
  routine,
  beforeTrip,
  afterWarning,
  afterLeakObservation,
}

extension FluidCheckContextX on FluidCheckContext {
  String get databaseValue => switch (this) {
    FluidCheckContext.routine => 'ROUTINE',
    FluidCheckContext.beforeTrip => 'BEFORE_TRIP',
    FluidCheckContext.afterWarning => 'AFTER_WARNING',
    FluidCheckContext.afterLeakObservation => 'AFTER_LEAK_OBSERVATION',
  };

  String get label => switch (this) {
    FluidCheckContext.routine => 'Contrôle régulier',
    FluidCheckContext.beforeTrip => 'Avant un trajet',
    FluidCheckContext.afterWarning => 'Après un voyant ou un message',
    FluidCheckContext.afterLeakObservation =>
      'Après une trace ou une fuite visible',
  };
}

enum FluidCareStatus {
  notChecked,
  notApplicable,
  normal,
  monitor,
  action,
  urgent,
}

extension FluidCareStatusX on FluidCareStatus {
  String get databaseValue => switch (this) {
    FluidCareStatus.notChecked => 'NOT_CHECKED',
    FluidCareStatus.notApplicable => 'NOT_APPLICABLE',
    FluidCareStatus.normal => 'NORMAL',
    FluidCareStatus.monitor => 'MONITOR',
    FluidCareStatus.action => 'ACTION',
    FluidCareStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    FluidCareStatus.notChecked => 'Non vérifié',
    FluidCareStatus.notApplicable => 'Non applicable au véhicule',
    FluidCareStatus.normal => 'Aspect habituel',
    FluidCareStatus.monitor => 'À surveiller',
    FluidCareStatus.action => 'Contrôle à prévoir',
    FluidCareStatus.urgent => 'Avis professionnel prioritaire',
  };
}

enum FluidCareLevel { ready, review, action, urgent }

extension FluidCareLevelX on FluidCareLevel {
  String get databaseValue => switch (this) {
    FluidCareLevel.ready => 'READY',
    FluidCareLevel.review => 'REVIEW',
    FluidCareLevel.action => 'ACTION',
    FluidCareLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    FluidCareLevel.ready => 'Contrôle complété',
    FluidCareLevel.review => 'Vérifications à terminer',
    FluidCareLevel.action => 'Contrôle recommandé',
    FluidCareLevel.urgent => 'Avis professionnel prioritaire',
  };
}

enum FluidCareArea {
  engineOilOrDriveUnit,
  coolingSystem,
  brakeFluid,
  washerFluid,
  additiveOrAdBlue,
  visibleLeaks,
  dashboardMessages,
  smokeSteamOrOdor,
  maintenanceDocuments,
  professionalCheckPlan,
}

extension FluidCareAreaX on FluidCareArea {
  String get databaseValue => switch (this) {
    FluidCareArea.engineOilOrDriveUnit => 'ENGINE_OIL_OR_DRIVE_UNIT',
    FluidCareArea.coolingSystem => 'COOLING_SYSTEM',
    FluidCareArea.brakeFluid => 'BRAKE_FLUID',
    FluidCareArea.washerFluid => 'WASHER_FLUID',
    FluidCareArea.additiveOrAdBlue => 'ADDITIVE_OR_ADBLUE',
    FluidCareArea.visibleLeaks => 'VISIBLE_LEAKS',
    FluidCareArea.dashboardMessages => 'DASHBOARD_MESSAGES',
    FluidCareArea.smokeSteamOrOdor => 'SMOKE_STEAM_OR_ODOR',
    FluidCareArea.maintenanceDocuments => 'MAINTENANCE_DOCUMENTS',
    FluidCareArea.professionalCheckPlan => 'PROFESSIONAL_CHECK_PLAN',
  };

  String get label => switch (this) {
    FluidCareArea.engineOilOrDriveUnit =>
      'Huile moteur ou contrôle du groupe motopropulseur',
    FluidCareArea.coolingSystem => 'Circuit de refroidissement visible',
    FluidCareArea.brakeFluid => 'Liquide de frein et messages associés',
    FluidCareArea.washerFluid => 'Lave-glace disponible',
    FluidCareArea.additiveOrAdBlue => 'Additif ou AdBlue selon le véhicule',
    FluidCareArea.visibleLeaks => 'Traces, gouttes ou suintements visibles',
    FluidCareArea.dashboardMessages => 'Voyants et messages liés aux niveaux',
    FluidCareArea.smokeSteamOrOdor => 'Fumée, vapeur ou odeur inhabituelle',
    FluidCareArea.maintenanceDocuments =>
      'Notice et historique d’entretien disponibles',
    FluidCareArea.professionalCheckPlan => 'Contrôle professionnel à prévoir',
  };

  bool get isSafetyCritical =>
      this == FluidCareArea.coolingSystem ||
      this == FluidCareArea.brakeFluid ||
      this == FluidCareArea.visibleLeaks ||
      this == FluidCareArea.dashboardMessages ||
      this == FluidCareArea.smokeSteamOrOdor;
}

class FluidCareProfile {
  const FluidCareProfile({
    required this.vehicleId,
    required this.checkedAt,
    required this.checkContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.visibleLeakObserved,
    required this.warningMessageOn,
    required this.electrifiedVehicle,
  });

  final String vehicleId;
  final DateTime checkedAt;
  final FluidCheckContext checkContext;
  final Map<FluidCareArea, FluidCareStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool visibleLeakObserved;
  final bool warningMessageOn;
  final bool electrifiedVehicle;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in FluidCareArea.values) {
      if (!checks.containsKey(area)) {
        throw FormatException('Le point « ${area.label} » est absent.');
      }
    }
    final reference = (now ?? DateTime.now()).toLocal();
    final selected = DateTime(checkedAt.year, checkedAt.month, checkedAt.day);
    final today = DateTime(reference.year, reference.month, reference.day);
    if (selected.isBefore(today.subtract(const Duration(days: 30)))) {
      throw const FormatException('La date du contrôle est trop ancienne.');
    }
    if (selected.isAfter(today.add(const Duration(days: 1)))) {
      throw const FormatException('La date du contrôle est dans le futur.');
    }
  }

  Map<String, dynamic> toMap() => {
    'vehicle_id': vehicleId,
    'checked_at': _dateValue(checkedAt),
    'check_context': checkContext.databaseValue,
    'vehicle_can_move_safely': vehicleCanMoveSafely,
    'visible_leak_observed': visibleLeakObserved,
    'warning_message_on': warningMessageOn,
    'electrified_vehicle': electrifiedVehicle,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class FluidCareFinding {
  const FluidCareFinding({
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

class FluidCareAssessment {
  const FluidCareAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final FluidCareLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<FluidCareFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required FluidCareProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — SUIVI DES NIVEAUX ET FLUIDES')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Contexte : ${profile.checkContext.label}')
      ..writeln('Date du contrôle : ${_formatDate(profile.checkedAt)}')
      ..writeln('État : ${level.label}')
      ..writeln('Indice déclaratif : $score/100')
      ..writeln('Points vérifiés : $completenessPercent %')
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
        'Ce résumé reprend uniquement des observations déclarées. Il ne mesure '
        'aucun niveau, ne diagnostique aucune fuite et ne remplace ni la notice '
        'du véhicule ni un professionnel. Ne mélangez pas des produits sans '
        'référence explicite du constructeur.',
      );
    return buffer.toString().trim();
  }
}

class FluidCareSnapshot {
  const FluidCareSnapshot({
    required this.id,
    required this.checkedAt,
    required this.checkContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime checkedAt;
  final FluidCheckContext checkContext;
  final FluidCareLevel level;
  final int score;
  final int completenessPercent;

  factory FluidCareSnapshot.fromMap(Map<String, dynamic> map) {
    return FluidCareSnapshot(
      id: map['id']?.toString() ?? '',
      checkedAt: DateTime.parse(map['checked_at'].toString()),
      checkContext: fluidCheckContextFromDatabase(
        map['check_context']?.toString(),
      ),
      level: fluidCareLevelFromDatabase(map['care_level']?.toString()),
      score: (map['care_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

FluidCheckContext fluidCheckContextFromDatabase(String? value) =>
    switch (value) {
      'BEFORE_TRIP' => FluidCheckContext.beforeTrip,
      'AFTER_WARNING' => FluidCheckContext.afterWarning,
      'AFTER_LEAK_OBSERVATION' => FluidCheckContext.afterLeakObservation,
      _ => FluidCheckContext.routine,
    };

FluidCareLevel fluidCareLevelFromDatabase(String? value) => switch (value) {
  'REVIEW' => FluidCareLevel.review,
  'ACTION' => FluidCareLevel.action,
  'URGENT' => FluidCareLevel.urgent,
  _ => FluidCareLevel.ready,
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
