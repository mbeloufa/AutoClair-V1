enum VisibilityCheckContext { routine, beforeTrip, nightDriving, badWeather }

extension VisibilityCheckContextX on VisibilityCheckContext {
  String get databaseValue => switch (this) {
    VisibilityCheckContext.routine => 'ROUTINE',
    VisibilityCheckContext.beforeTrip => 'BEFORE_TRIP',
    VisibilityCheckContext.nightDriving => 'NIGHT_DRIVING',
    VisibilityCheckContext.badWeather => 'BAD_WEATHER',
  };

  String get label => switch (this) {
    VisibilityCheckContext.routine => 'Contrôle régulier',
    VisibilityCheckContext.beforeTrip => 'Avant un trajet',
    VisibilityCheckContext.nightDriving => 'Avant de rouler de nuit',
    VisibilityCheckContext.badWeather => 'Avant une météo dégradée',
  };
}

enum VisibilityCareStatus {
  notChecked,
  notApplicable,
  normal,
  monitor,
  action,
  urgent,
}

extension VisibilityCareStatusX on VisibilityCareStatus {
  String get databaseValue => switch (this) {
    VisibilityCareStatus.notChecked => 'NOT_CHECKED',
    VisibilityCareStatus.notApplicable => 'NOT_APPLICABLE',
    VisibilityCareStatus.normal => 'NORMAL',
    VisibilityCareStatus.monitor => 'MONITOR',
    VisibilityCareStatus.action => 'ACTION',
    VisibilityCareStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    VisibilityCareStatus.notChecked => 'Non vérifié',
    VisibilityCareStatus.notApplicable => 'Non applicable au véhicule',
    VisibilityCareStatus.normal => 'Fonctionnement habituel',
    VisibilityCareStatus.monitor => 'À surveiller',
    VisibilityCareStatus.action => 'Contrôle à prévoir',
    VisibilityCareStatus.urgent => 'Avis professionnel prioritaire',
  };
}

enum VisibilityCareLevel { ready, review, action, urgent }

extension VisibilityCareLevelX on VisibilityCareLevel {
  String get databaseValue => switch (this) {
    VisibilityCareLevel.ready => 'READY',
    VisibilityCareLevel.review => 'REVIEW',
    VisibilityCareLevel.action => 'ACTION',
    VisibilityCareLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    VisibilityCareLevel.ready => 'Contrôle complété',
    VisibilityCareLevel.review => 'Vérifications à terminer',
    VisibilityCareLevel.action => 'Contrôle recommandé',
    VisibilityCareLevel.urgent => 'Avis professionnel prioritaire',
  };
}

enum VisibilityCareArea {
  lowAndHighBeams,
  indicatorsAndHazards,
  brakeAndRearLights,
  fogAndReversingLights,
  windshieldAndGlass,
  wipers,
  washerSystem,
  mirrors,
  demistingAndDefrosting,
  professionalCheckPlan,
}

extension VisibilityCareAreaX on VisibilityCareArea {
  String get databaseValue => switch (this) {
    VisibilityCareArea.lowAndHighBeams => 'LOW_AND_HIGH_BEAMS',
    VisibilityCareArea.indicatorsAndHazards => 'INDICATORS_AND_HAZARDS',
    VisibilityCareArea.brakeAndRearLights => 'BRAKE_AND_REAR_LIGHTS',
    VisibilityCareArea.fogAndReversingLights => 'FOG_AND_REVERSING_LIGHTS',
    VisibilityCareArea.windshieldAndGlass => 'WINDSHIELD_AND_GLASS',
    VisibilityCareArea.wipers => 'WIPERS',
    VisibilityCareArea.washerSystem => 'WASHER_SYSTEM',
    VisibilityCareArea.mirrors => 'MIRRORS',
    VisibilityCareArea.demistingAndDefrosting => 'DEMISTING_AND_DEFROSTING',
    VisibilityCareArea.professionalCheckPlan => 'PROFESSIONAL_CHECK_PLAN',
  };

  String get label => switch (this) {
    VisibilityCareArea.lowAndHighBeams => 'Feux de croisement et de route',
    VisibilityCareArea.indicatorsAndHazards =>
      'Clignotants et feux de détresse',
    VisibilityCareArea.brakeAndRearLights =>
      'Feux stop, position et éclairage arrière',
    VisibilityCareArea.fogAndReversingLights =>
      'Antibrouillards et feux de recul',
    VisibilityCareArea.windshieldAndGlass =>
      'Pare-brise et vitrages dans le champ de vision',
    VisibilityCareArea.wipers => 'Essuie-glaces et qualité d’essuyage',
    VisibilityCareArea.washerSystem => 'Lave-glace et projection visible',
    VisibilityCareArea.mirrors => 'Rétroviseurs et visibilité latérale',
    VisibilityCareArea.demistingAndDefrosting => 'Désembuage et dégivrage',
    VisibilityCareArea.professionalCheckPlan =>
      'Contrôle professionnel à prévoir',
  };

  bool get isSafetyCritical =>
      this == VisibilityCareArea.lowAndHighBeams ||
      this == VisibilityCareArea.indicatorsAndHazards ||
      this == VisibilityCareArea.brakeAndRearLights ||
      this == VisibilityCareArea.windshieldAndGlass ||
      this == VisibilityCareArea.wipers ||
      this == VisibilityCareArea.demistingAndDefrosting;
}

class VisibilityCareProfile {
  const VisibilityCareProfile({
    required this.vehicleId,
    required this.checkedAt,
    required this.checkContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.majorVisibilityObstruction,
    required this.essentialLightFailure,
    required this.badWeatherExpected,
  });

  final String vehicleId;
  final DateTime checkedAt;
  final VisibilityCheckContext checkContext;
  final Map<VisibilityCareArea, VisibilityCareStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool majorVisibilityObstruction;
  final bool essentialLightFailure;
  final bool badWeatherExpected;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in VisibilityCareArea.values) {
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
    'major_visibility_obstruction': majorVisibilityObstruction,
    'essential_light_failure': essentialLightFailure,
    'bad_weather_expected': badWeatherExpected,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class VisibilityCareFinding {
  const VisibilityCareFinding({
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

class VisibilityCareAssessment {
  const VisibilityCareAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final VisibilityCareLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<VisibilityCareFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required VisibilityCareProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — ÉCLAIRAGE ET VISIBILITÉ')
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
        'Ce résumé reprend uniquement des observations déclarées. Il ne '
        'diagnostique aucun circuit électrique, ne garantit ni la conformité '
        'du véhicule ni la sécurité d’un trajet et ne remplace pas un '
        'professionnel ou la notice du véhicule.',
      );
    return buffer.toString().trim();
  }
}

class VisibilityCareSnapshot {
  const VisibilityCareSnapshot({
    required this.id,
    required this.checkedAt,
    required this.checkContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime checkedAt;
  final VisibilityCheckContext checkContext;
  final VisibilityCareLevel level;
  final int score;
  final int completenessPercent;

  factory VisibilityCareSnapshot.fromMap(Map<String, dynamic> map) {
    return VisibilityCareSnapshot(
      id: map['id']?.toString() ?? '',
      checkedAt: DateTime.parse(map['checked_at'].toString()),
      checkContext: visibilityCheckContextFromDatabase(
        map['check_context']?.toString(),
      ),
      level: visibilityCareLevelFromDatabase(map['care_level']?.toString()),
      score: (map['care_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

VisibilityCheckContext visibilityCheckContextFromDatabase(String? value) =>
    switch (value) {
      'BEFORE_TRIP' => VisibilityCheckContext.beforeTrip,
      'NIGHT_DRIVING' => VisibilityCheckContext.nightDriving,
      'BAD_WEATHER' => VisibilityCheckContext.badWeather,
      _ => VisibilityCheckContext.routine,
    };

VisibilityCareLevel visibilityCareLevelFromDatabase(String? value) =>
    switch (value) {
      'REVIEW' => VisibilityCareLevel.review,
      'ACTION' => VisibilityCareLevel.action,
      'URGENT' => VisibilityCareLevel.urgent,
      _ => VisibilityCareLevel.ready,
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
