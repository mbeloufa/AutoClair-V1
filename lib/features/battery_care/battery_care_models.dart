enum BatteryCheckContext {
  routine,
  beforeTrip,
  afterLongParking,
  afterDifficultStart,
}

extension BatteryCheckContextX on BatteryCheckContext {
  String get databaseValue => switch (this) {
    BatteryCheckContext.routine => 'ROUTINE',
    BatteryCheckContext.beforeTrip => 'BEFORE_TRIP',
    BatteryCheckContext.afterLongParking => 'AFTER_LONG_PARKING',
    BatteryCheckContext.afterDifficultStart => 'AFTER_DIFFICULT_START',
  };

  String get label => switch (this) {
    BatteryCheckContext.routine => 'Contrôle régulier',
    BatteryCheckContext.beforeTrip => 'Avant un trajet',
    BatteryCheckContext.afterLongParking => 'Après une immobilisation',
    BatteryCheckContext.afterDifficultStart => 'Après un démarrage difficile',
  };
}

enum BatteryCareStatus { notChecked, normal, monitor, action, urgent }

extension BatteryCareStatusX on BatteryCareStatus {
  String get databaseValue => switch (this) {
    BatteryCareStatus.notChecked => 'NOT_CHECKED',
    BatteryCareStatus.normal => 'NORMAL',
    BatteryCareStatus.monitor => 'MONITOR',
    BatteryCareStatus.action => 'ACTION',
    BatteryCareStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    BatteryCareStatus.notChecked => 'Non vérifié',
    BatteryCareStatus.normal => 'Comportement habituel',
    BatteryCareStatus.monitor => 'À surveiller',
    BatteryCareStatus.action => 'Contrôle à prévoir',
    BatteryCareStatus.urgent => 'Avis professionnel prioritaire',
  };
}

enum BatteryCareLevel { ready, review, action, urgent }

extension BatteryCareLevelX on BatteryCareLevel {
  String get databaseValue => switch (this) {
    BatteryCareLevel.ready => 'READY',
    BatteryCareLevel.review => 'REVIEW',
    BatteryCareLevel.action => 'ACTION',
    BatteryCareLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    BatteryCareLevel.ready => 'Contrôle complété',
    BatteryCareLevel.review => 'Vérifications à terminer',
    BatteryCareLevel.action => 'Contrôle recommandé',
    BatteryCareLevel.urgent => 'Avis professionnel prioritaire',
  };
}

enum BatteryCareArea {
  startingBehavior,
  dashboardWarnings,
  visibleConnections,
  electricalAccessories,
  stopStartBehavior,
  recentDischargeHistory,
  longParkingPreparation,
  assistanceEquipment,
  professionalTest,
  emergencyPlan,
}

extension BatteryCareAreaX on BatteryCareArea {
  String get databaseValue => switch (this) {
    BatteryCareArea.startingBehavior => 'STARTING_BEHAVIOR',
    BatteryCareArea.dashboardWarnings => 'DASHBOARD_WARNINGS',
    BatteryCareArea.visibleConnections => 'VISIBLE_CONNECTIONS',
    BatteryCareArea.electricalAccessories => 'ELECTRICAL_ACCESSORIES',
    BatteryCareArea.stopStartBehavior => 'STOP_START_BEHAVIOR',
    BatteryCareArea.recentDischargeHistory => 'RECENT_DISCHARGE_HISTORY',
    BatteryCareArea.longParkingPreparation => 'LONG_PARKING_PREPARATION',
    BatteryCareArea.assistanceEquipment => 'ASSISTANCE_EQUIPMENT',
    BatteryCareArea.professionalTest => 'PROFESSIONAL_TEST',
    BatteryCareArea.emergencyPlan => 'EMERGENCY_PLAN',
  };

  String get label => switch (this) {
    BatteryCareArea.startingBehavior => 'Vitesse et régularité du démarrage',
    BatteryCareArea.dashboardWarnings => 'Voyants de batterie ou de charge',
    BatteryCareArea.visibleConnections =>
      'Aspect visible des connexions accessibles',
    BatteryCareArea.electricalAccessories =>
      'Éclairage et accessoires électriques',
    BatteryCareArea.stopStartBehavior =>
      'Fonctionnement du système Stop & Start',
    BatteryCareArea.recentDischargeHistory =>
      'Décharge ou panne récente connue',
    BatteryCareArea.longParkingPreparation =>
      'Préparation après une longue immobilisation',
    BatteryCareArea.assistanceEquipment =>
      'Moyen d’assistance et notice disponibles',
    BatteryCareArea.professionalTest => 'Test professionnel à prévoir',
    BatteryCareArea.emergencyPlan => 'Solution prévue en cas de non-démarrage',
  };

  bool get isSafetyCritical =>
      this == BatteryCareArea.dashboardWarnings ||
      this == BatteryCareArea.visibleConnections ||
      this == BatteryCareArea.startingBehavior;
}

class BatteryCareProfile {
  const BatteryCareProfile({
    required this.vehicleId,
    required this.checkedAt,
    required this.checkContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.difficultStart,
    required this.recentDischarge,
    required this.parkedMoreThan14Days,
  });

  final String vehicleId;
  final DateTime checkedAt;
  final BatteryCheckContext checkContext;
  final Map<BatteryCareArea, BatteryCareStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool difficultStart;
  final bool recentDischarge;
  final bool parkedMoreThan14Days;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in BatteryCareArea.values) {
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
    'difficult_start': difficultStart,
    'recent_discharge': recentDischarge,
    'parked_more_than_14_days': parkedMoreThan14Days,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class BatteryCareFinding {
  const BatteryCareFinding({
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

class BatteryCareAssessment {
  const BatteryCareAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final BatteryCareLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<BatteryCareFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required BatteryCareProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — SUIVI DE LA BATTERIE')
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
        'aucune tension, ne diagnostique pas la batterie, ne prédit pas sa durée '
        'de vie et ne remplace ni la notice du véhicule ni un professionnel.',
      );
    return buffer.toString().trim();
  }
}

class BatteryCareSnapshot {
  const BatteryCareSnapshot({
    required this.id,
    required this.checkedAt,
    required this.checkContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime checkedAt;
  final BatteryCheckContext checkContext;
  final BatteryCareLevel level;
  final int score;
  final int completenessPercent;

  factory BatteryCareSnapshot.fromMap(Map<String, dynamic> map) {
    return BatteryCareSnapshot(
      id: map['id']?.toString() ?? '',
      checkedAt: DateTime.parse(map['checked_at'].toString()),
      checkContext: batteryCheckContextFromDatabase(
        map['check_context']?.toString(),
      ),
      level: batteryCareLevelFromDatabase(map['care_level']?.toString()),
      score: (map['care_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

BatteryCheckContext batteryCheckContextFromDatabase(String? value) =>
    switch (value) {
      'BEFORE_TRIP' => BatteryCheckContext.beforeTrip,
      'AFTER_LONG_PARKING' => BatteryCheckContext.afterLongParking,
      'AFTER_DIFFICULT_START' => BatteryCheckContext.afterDifficultStart,
      _ => BatteryCheckContext.routine,
    };

BatteryCareLevel batteryCareLevelFromDatabase(String? value) => switch (value) {
  'REVIEW' => BatteryCareLevel.review,
  'ACTION' => BatteryCareLevel.action,
  'URGENT' => BatteryCareLevel.urgent,
  _ => BatteryCareLevel.ready,
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
