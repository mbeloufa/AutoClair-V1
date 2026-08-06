enum BrakeCheckContext { routine, beforeTrip, unusualBraking, afterImpact }

extension BrakeCheckContextX on BrakeCheckContext {
  String get databaseValue => switch (this) {
    BrakeCheckContext.routine => 'ROUTINE',
    BrakeCheckContext.beforeTrip => 'BEFORE_TRIP',
    BrakeCheckContext.unusualBraking => 'UNUSUAL_BRAKING',
    BrakeCheckContext.afterImpact => 'AFTER_IMPACT',
  };

  String get label => switch (this) {
    BrakeCheckContext.routine => 'Contrôle régulier',
    BrakeCheckContext.beforeTrip => 'Avant un trajet',
    BrakeCheckContext.unusualBraking =>
      'Après une sensation de freinage inhabituelle',
    BrakeCheckContext.afterImpact => 'Après un choc ou un nid-de-poule',
  };
}

enum BrakeCareStatus {
  notChecked,
  notApplicable,
  normal,
  monitor,
  action,
  urgent,
}

extension BrakeCareStatusX on BrakeCareStatus {
  String get databaseValue => switch (this) {
    BrakeCareStatus.notChecked => 'NOT_CHECKED',
    BrakeCareStatus.notApplicable => 'NOT_APPLICABLE',
    BrakeCareStatus.normal => 'NORMAL',
    BrakeCareStatus.monitor => 'MONITOR',
    BrakeCareStatus.action => 'ACTION',
    BrakeCareStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    BrakeCareStatus.notChecked => 'Non vérifié',
    BrakeCareStatus.notApplicable => 'Non applicable au véhicule',
    BrakeCareStatus.normal => 'Comportement habituel',
    BrakeCareStatus.monitor => 'À surveiller',
    BrakeCareStatus.action => 'Contrôle à prévoir',
    BrakeCareStatus.urgent => 'Avis professionnel prioritaire',
  };
}

enum BrakeCareLevel { ready, review, action, urgent }

extension BrakeCareLevelX on BrakeCareLevel {
  String get databaseValue => switch (this) {
    BrakeCareLevel.ready => 'READY',
    BrakeCareLevel.review => 'REVIEW',
    BrakeCareLevel.action => 'ACTION',
    BrakeCareLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    BrakeCareLevel.ready => 'Contrôle complété',
    BrakeCareLevel.review => 'Vérifications à terminer',
    BrakeCareLevel.action => 'Contrôle recommandé',
    BrakeCareLevel.urgent => 'Avis professionnel prioritaire',
  };
}

enum BrakeCareArea {
  pedalFeel,
  brakingResponse,
  warningLights,
  brakingNoises,
  brakingVibrations,
  parkingBrake,
  directionalStability,
  steeringFeel,
  wheelAndSuspensionSigns,
  professionalCheckPlan,
}

extension BrakeCareAreaX on BrakeCareArea {
  String get databaseValue => switch (this) {
    BrakeCareArea.pedalFeel => 'PEDAL_FEEL',
    BrakeCareArea.brakingResponse => 'BRAKING_RESPONSE',
    BrakeCareArea.warningLights => 'WARNING_LIGHTS',
    BrakeCareArea.brakingNoises => 'BRAKING_NOISES',
    BrakeCareArea.brakingVibrations => 'BRAKING_VIBRATIONS',
    BrakeCareArea.parkingBrake => 'PARKING_BRAKE',
    BrakeCareArea.directionalStability => 'DIRECTIONAL_STABILITY',
    BrakeCareArea.steeringFeel => 'STEERING_FEEL',
    BrakeCareArea.wheelAndSuspensionSigns => 'WHEEL_AND_SUSPENSION_SIGNS',
    BrakeCareArea.professionalCheckPlan => 'PROFESSIONAL_CHECK_PLAN',
  };

  String get label => switch (this) {
    BrakeCareArea.pedalFeel => 'Sensation de la pédale de frein',
    BrakeCareArea.brakingResponse => 'Réponse du freinage déclarée',
    BrakeCareArea.warningLights => 'Voyants freinage, ABS ou stabilité',
    BrakeCareArea.brakingNoises => 'Bruits au freinage',
    BrakeCareArea.brakingVibrations => 'Vibrations au freinage',
    BrakeCareArea.parkingBrake => 'Frein de stationnement',
    BrakeCareArea.directionalStability =>
      'Stabilité et déviation en ligne droite',
    BrakeCareArea.steeringFeel => 'Direction, point dur ou jeu ressenti',
    BrakeCareArea.wheelAndSuspensionSigns =>
      'Roues, suspension et signes visibles',
    BrakeCareArea.professionalCheckPlan => 'Contrôle professionnel à prévoir',
  };

  bool get isSafetyCritical =>
      this == BrakeCareArea.pedalFeel ||
      this == BrakeCareArea.brakingResponse ||
      this == BrakeCareArea.warningLights ||
      this == BrakeCareArea.brakingVibrations ||
      this == BrakeCareArea.directionalStability ||
      this == BrakeCareArea.steeringFeel ||
      this == BrakeCareArea.wheelAndSuspensionSigns;
}

class BrakeCareProfile {
  const BrakeCareProfile({
    required this.vehicleId,
    required this.checkedAt,
    required this.checkContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.brakingAnomaly,
    required this.steeringInstability,
    required this.recentImpact,
  });

  final String vehicleId;
  final DateTime checkedAt;
  final BrakeCheckContext checkContext;
  final Map<BrakeCareArea, BrakeCareStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool brakingAnomaly;
  final bool steeringInstability;
  final bool recentImpact;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in BrakeCareArea.values) {
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
    'braking_anomaly': brakingAnomaly,
    'steering_instability': steeringInstability,
    'recent_impact': recentImpact,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class BrakeCareFinding {
  const BrakeCareFinding({
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

class BrakeCareAssessment {
  const BrakeCareAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final BrakeCareLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<BrakeCareFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required BrakeCareProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — FREINAGE ET TENUE DE ROUTE')
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
        'Ce résumé reprend uniquement des sensations et observations déclarées. '
        'Il ne diagnostique aucun système de freinage ou de direction, ne mesure '
        'ni distance d’arrêt ni usure et ne garantit pas la sécurité du véhicule. '
        'Un professionnel et la notice du véhicule restent les références.',
      );
    return buffer.toString().trim();
  }
}

class BrakeCareSnapshot {
  const BrakeCareSnapshot({
    required this.id,
    required this.checkedAt,
    required this.checkContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime checkedAt;
  final BrakeCheckContext checkContext;
  final BrakeCareLevel level;
  final int score;
  final int completenessPercent;

  factory BrakeCareSnapshot.fromMap(Map<String, dynamic> map) {
    return BrakeCareSnapshot(
      id: map['id']?.toString() ?? '',
      checkedAt: DateTime.parse(map['checked_at'].toString()),
      checkContext: brakeCheckContextFromDatabase(
        map['check_context']?.toString(),
      ),
      level: brakeCareLevelFromDatabase(map['care_level']?.toString()),
      score: (map['care_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

BrakeCheckContext brakeCheckContextFromDatabase(String? value) =>
    switch (value) {
      'BEFORE_TRIP' => BrakeCheckContext.beforeTrip,
      'UNUSUAL_BRAKING' => BrakeCheckContext.unusualBraking,
      'AFTER_IMPACT' => BrakeCheckContext.afterImpact,
      _ => BrakeCheckContext.routine,
    };

BrakeCareLevel brakeCareLevelFromDatabase(String? value) => switch (value) {
  'REVIEW' => BrakeCareLevel.review,
  'ACTION' => BrakeCareLevel.action,
  'URGENT' => BrakeCareLevel.urgent,
  _ => BrakeCareLevel.ready,
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
