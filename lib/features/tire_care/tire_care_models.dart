enum TireCheckContext { routine, beforeTrip, seasonalChange, afterImpact }

extension TireCheckContextX on TireCheckContext {
  String get databaseValue => switch (this) {
    TireCheckContext.routine => 'ROUTINE',
    TireCheckContext.beforeTrip => 'BEFORE_TRIP',
    TireCheckContext.seasonalChange => 'SEASONAL_CHANGE',
    TireCheckContext.afterImpact => 'AFTER_IMPACT',
  };

  String get label => switch (this) {
    TireCheckContext.routine => 'Contrôle régulier',
    TireCheckContext.beforeTrip => 'Avant un trajet',
    TireCheckContext.seasonalChange => 'Changement de saison',
    TireCheckContext.afterImpact => 'Après un choc ou un nid-de-poule',
  };
}

enum TireCareStatus { notChecked, good, monitor, action, urgent }

extension TireCareStatusX on TireCareStatus {
  String get databaseValue => switch (this) {
    TireCareStatus.notChecked => 'NOT_CHECKED',
    TireCareStatus.good => 'GOOD',
    TireCareStatus.monitor => 'MONITOR',
    TireCareStatus.action => 'ACTION',
    TireCareStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    TireCareStatus.notChecked => 'Non vérifié',
    TireCareStatus.good => 'Aspect satisfaisant',
    TireCareStatus.monitor => 'À surveiller',
    TireCareStatus.action => 'Action à prévoir',
    TireCareStatus.urgent => 'Avis professionnel prioritaire',
  };
}

enum TireCareLevel { ready, review, action, urgent }

extension TireCareLevelX on TireCareLevel {
  String get databaseValue => switch (this) {
    TireCareLevel.ready => 'READY',
    TireCareLevel.review => 'REVIEW',
    TireCareLevel.action => 'ACTION',
    TireCareLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    TireCareLevel.ready => 'Contrôle complété',
    TireCareLevel.review => 'Vérifications à terminer',
    TireCareLevel.action => 'Actions recommandées',
    TireCareLevel.urgent => 'Avis professionnel prioritaire',
  };
}

enum TireCareArea {
  pressureReference,
  visibleTread,
  sidewalls,
  unevenWear,
  punctureHistory,
  wheelFastening,
  vibrationsAlignment,
  spareOrRepairKit,
  seasonalSuitability,
  professionalCheck,
}

extension TireCareAreaX on TireCareArea {
  String get databaseValue => switch (this) {
    TireCareArea.pressureReference => 'PRESSURE_REFERENCE',
    TireCareArea.visibleTread => 'VISIBLE_TREAD',
    TireCareArea.sidewalls => 'SIDEWALLS',
    TireCareArea.unevenWear => 'UNEVEN_WEAR',
    TireCareArea.punctureHistory => 'PUNCTURE_HISTORY',
    TireCareArea.wheelFastening => 'WHEEL_FASTENING',
    TireCareArea.vibrationsAlignment => 'VIBRATIONS_ALIGNMENT',
    TireCareArea.spareOrRepairKit => 'SPARE_OR_REPAIR_KIT',
    TireCareArea.seasonalSuitability => 'SEASONAL_SUITABILITY',
    TireCareArea.professionalCheck => 'PROFESSIONAL_CHECK',
  };

  String get label => switch (this) {
    TireCareArea.pressureReference =>
      'Pression comparée à la recommandation du véhicule',
    TireCareArea.visibleTread => 'Usure visible de la bande de roulement',
    TireCareArea.sidewalls => 'Flancs, coupures, hernies ou craquelures',
    TireCareArea.unevenWear => 'Usure irrégulière entre les pneus',
    TireCareArea.punctureHistory => 'Crevaison ou réparation connue',
    TireCareArea.wheelFastening => 'Fixation apparente des roues',
    TireCareArea.vibrationsAlignment => 'Vibrations, tirage ou tenue de cap',
    TireCareArea.spareOrRepairKit => 'Roue de secours ou kit de réparation',
    TireCareArea.seasonalSuitability =>
      'Adéquation aux conditions et à la saison',
    TireCareArea.professionalCheck => 'Contrôle professionnel à prévoir',
  };

  bool get isSafetyCritical =>
      this == TireCareArea.pressureReference ||
      this == TireCareArea.sidewalls ||
      this == TireCareArea.wheelFastening ||
      this == TireCareArea.vibrationsAlignment;
}

class TireCareProfile {
  const TireCareProfile({
    required this.vehicleId,
    required this.checkedAt,
    required this.checkContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.vibrationOrPulling,
    required this.recentImpact,
  });

  final String vehicleId;
  final DateTime checkedAt;
  final TireCheckContext checkContext;
  final Map<TireCareArea, TireCareStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool vibrationOrPulling;
  final bool recentImpact;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in TireCareArea.values) {
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
    'vibration_or_pulling': vibrationOrPulling,
    'recent_impact': recentImpact,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class TireCareFinding {
  const TireCareFinding({
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

class TireCareAssessment {
  const TireCareAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final TireCareLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<TireCareFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required TireCareProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — SUIVI DES PNEUS')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Contexte : ${profile.checkContext.label}')
      ..writeln('Date du contrôle : ${_formatDate(profile.checkedAt)}')
      ..writeln('État : ${level.label}')
      ..writeln('Indice visuel : $score/100')
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
        'Ce résumé reprend uniquement des observations déclarées. Il ne fixe '
        'aucune pression constructeur, ne confirme pas la conformité d’un pneu '
        'et ne remplace pas le contrôle d’un professionnel.',
      );
    return buffer.toString().trim();
  }
}

class TireCareSnapshot {
  const TireCareSnapshot({
    required this.id,
    required this.checkedAt,
    required this.checkContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime checkedAt;
  final TireCheckContext checkContext;
  final TireCareLevel level;
  final int score;
  final int completenessPercent;

  factory TireCareSnapshot.fromMap(Map<String, dynamic> map) {
    return TireCareSnapshot(
      id: map['id']?.toString() ?? '',
      checkedAt: DateTime.parse(map['checked_at'].toString()),
      checkContext: tireCheckContextFromDatabase(
        map['check_context']?.toString(),
      ),
      level: tireCareLevelFromDatabase(map['care_level']?.toString()),
      score: (map['care_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

TireCheckContext tireCheckContextFromDatabase(String? value) => switch (value) {
  'BEFORE_TRIP' => TireCheckContext.beforeTrip,
  'SEASONAL_CHANGE' => TireCheckContext.seasonalChange,
  'AFTER_IMPACT' => TireCheckContext.afterImpact,
  _ => TireCheckContext.routine,
};

TireCareLevel tireCareLevelFromDatabase(String? value) => switch (value) {
  'REVIEW' => TireCareLevel.review,
  'ACTION' => TireCareLevel.action,
  'URGENT' => TireCareLevel.urgent,
  _ => TireCareLevel.ready,
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
