enum TripPurpose { everyday, weekend, holiday, longJourney, winter }

extension TripPurposeX on TripPurpose {
  String get databaseValue => switch (this) {
    TripPurpose.everyday => 'EVERYDAY',
    TripPurpose.weekend => 'WEEKEND',
    TripPurpose.holiday => 'HOLIDAY',
    TripPurpose.longJourney => 'LONG_JOURNEY',
    TripPurpose.winter => 'WINTER',
  };

  String get label => switch (this) {
    TripPurpose.everyday => 'Déplacement habituel',
    TripPurpose.weekend => 'Week-end',
    TripPurpose.holiday => 'Départ en vacances',
    TripPurpose.longJourney => 'Long trajet',
    TripPurpose.winter => 'Trajet hivernal',
  };
}

enum TripCheckStatus { notChecked, ready, attention, blocking }

extension TripCheckStatusX on TripCheckStatus {
  String get databaseValue => switch (this) {
    TripCheckStatus.notChecked => 'NOT_CHECKED',
    TripCheckStatus.ready => 'READY',
    TripCheckStatus.attention => 'ATTENTION',
    TripCheckStatus.blocking => 'BLOCKING',
  };

  String get label => switch (this) {
    TripCheckStatus.notChecked => 'Non vérifié',
    TripCheckStatus.ready => 'Prêt',
    TripCheckStatus.attention => 'À vérifier',
    TripCheckStatus.blocking => 'À corriger avant le départ',
  };
}

enum TripReadinessLevel { ready, review, action, blocked }

extension TripReadinessLevelX on TripReadinessLevel {
  String get databaseValue => switch (this) {
    TripReadinessLevel.ready => 'READY',
    TripReadinessLevel.review => 'REVIEW',
    TripReadinessLevel.action => 'ACTION',
    TripReadinessLevel.blocked => 'BLOCKED',
  };

  String get label => switch (this) {
    TripReadinessLevel.ready => 'Départ bien préparé',
    TripReadinessLevel.review => 'Vérifications à terminer',
    TripReadinessLevel.action => 'Actions recommandées',
    TripReadinessLevel.blocked => 'Départ à reporter ou sécuriser',
  };
}

enum TripReadinessArea {
  vehicleDocuments,
  tires,
  fluids,
  lights,
  safetyEquipment,
  load,
  driverRest,
  passengers,
  routeBreaks,
  emergencyKit,
}

extension TripReadinessAreaX on TripReadinessArea {
  String get databaseValue => switch (this) {
    TripReadinessArea.vehicleDocuments => 'VEHICLE_DOCUMENTS',
    TripReadinessArea.tires => 'TIRES',
    TripReadinessArea.fluids => 'FLUIDS',
    TripReadinessArea.lights => 'LIGHTS',
    TripReadinessArea.safetyEquipment => 'SAFETY_EQUIPMENT',
    TripReadinessArea.load => 'LOAD',
    TripReadinessArea.driverRest => 'DRIVER_REST',
    TripReadinessArea.passengers => 'PASSENGERS',
    TripReadinessArea.routeBreaks => 'ROUTE_BREAKS',
    TripReadinessArea.emergencyKit => 'EMERGENCY_KIT',
  };

  String get label => switch (this) {
    TripReadinessArea.vehicleDocuments => 'Documents du véhicule',
    TripReadinessArea.tires => 'Pneus et pression',
    TripReadinessArea.fluids => 'Niveaux et absence de fuite',
    TripReadinessArea.lights => 'Éclairage et visibilité',
    TripReadinessArea.safetyEquipment => 'Équipements de sécurité',
    TripReadinessArea.load => 'Chargement et arrimage',
    TripReadinessArea.driverRest => 'Repos et aptitude du conducteur',
    TripReadinessArea.passengers => 'Passagers et sièges adaptés',
    TripReadinessArea.routeBreaks => 'Pauses et organisation du trajet',
    TripReadinessArea.emergencyKit => 'Kit utile en cas d’imprévu',
  };

  bool get isSafetyCritical =>
      this == TripReadinessArea.tires ||
      this == TripReadinessArea.fluids ||
      this == TripReadinessArea.lights ||
      this == TripReadinessArea.load ||
      this == TripReadinessArea.driverRest;
}

class TripReadinessProfile {
  const TripReadinessProfile({
    required this.vehicleId,
    required this.departureDate,
    required this.purpose,
    required this.checks,
    required this.longDistance,
    required this.towing,
    required this.coldConditions,
    required this.youngPassengers,
    required this.breakdownCoverageKnown,
  });

  final String vehicleId;
  final DateTime departureDate;
  final TripPurpose purpose;
  final Map<TripReadinessArea, TripCheckStatus> checks;
  final bool longDistance;
  final bool towing;
  final bool coldConditions;
  final bool youngPassengers;
  final bool breakdownCoverageKnown;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in TripReadinessArea.values) {
      if (!checks.containsKey(area)) {
        throw FormatException('Le point « ${area.label} » est absent.');
      }
    }
    final reference = (now ?? DateTime.now()).toLocal();
    final selected = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );
    final today = DateTime(reference.year, reference.month, reference.day);
    if (selected.isBefore(today.subtract(const Duration(days: 1)))) {
      throw const FormatException('La date de départ est déjà passée.');
    }
    if (selected.isAfter(today.add(const Duration(days: 366)))) {
      throw const FormatException('La date de départ est trop éloignée.');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'departure_date': _dateValue(departureDate),
      'purpose': purpose.databaseValue,
      'long_distance': longDistance,
      'towing': towing,
      'cold_conditions': coldConditions,
      'young_passengers': youngPassengers,
      'breakdown_coverage_known': breakdownCoverageKnown,
      'checks': {
        for (final entry in checks.entries)
          entry.key.databaseValue: entry.value.databaseValue,
      },
    };
  }
}

class TripReadinessFinding {
  const TripReadinessFinding({
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

class TripReadinessAssessment {
  const TripReadinessAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.blockingCount,
    required this.findings,
  });

  final TripReadinessLevel level;
  final int score;
  final int completenessPercent;
  final int blockingCount;
  final List<TripReadinessFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required TripReadinessProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — PRÉPARATION AVANT DÉPART')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Date prévue : ${_formatDate(profile.departureDate)}')
      ..writeln('Contexte : ${profile.purpose.label}')
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
        'AutoClair n’enregistre ni destination ni itinéraire. Cette checklist '
        'ne remplace pas les consignes officielles, la météo, le trafic ou un '
        'contrôle professionnel du véhicule.',
      );
    return buffer.toString().trim();
  }
}

class TripReadinessSnapshot {
  const TripReadinessSnapshot({
    required this.id,
    required this.departureDate,
    required this.purpose,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime departureDate;
  final TripPurpose purpose;
  final TripReadinessLevel level;
  final int score;
  final int completenessPercent;

  factory TripReadinessSnapshot.fromMap(Map<String, dynamic> map) {
    return TripReadinessSnapshot(
      id: map['id']?.toString() ?? '',
      departureDate: DateTime.parse(map['departure_date'].toString()),
      purpose: tripPurposeFromDatabase(map['purpose']?.toString()),
      level: tripReadinessLevelFromDatabase(map['readiness_level']?.toString()),
      score: (map['readiness_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

TripPurpose tripPurposeFromDatabase(String? value) => switch (value) {
  'WEEKEND' => TripPurpose.weekend,
  'HOLIDAY' => TripPurpose.holiday,
  'LONG_JOURNEY' => TripPurpose.longJourney,
  'WINTER' => TripPurpose.winter,
  _ => TripPurpose.everyday,
};

TripReadinessLevel tripReadinessLevelFromDatabase(String? value) =>
    switch (value) {
      'REVIEW' => TripReadinessLevel.review,
      'ACTION' => TripReadinessLevel.action,
      'BLOCKED' => TripReadinessLevel.blocked,
      _ => TripReadinessLevel.ready,
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
