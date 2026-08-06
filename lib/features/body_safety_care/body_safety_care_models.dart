enum BodySafetyCheckContext {
  routine,
  beforeTrip,
  afterImpact,
  beforeControlOrSale,
}

extension BodySafetyCheckContextX on BodySafetyCheckContext {
  String get databaseValue => switch (this) {
    BodySafetyCheckContext.routine => 'ROUTINE',
    BodySafetyCheckContext.beforeTrip => 'BEFORE_TRIP',
    BodySafetyCheckContext.afterImpact => 'AFTER_IMPACT',
    BodySafetyCheckContext.beforeControlOrSale => 'BEFORE_CONTROL_OR_SALE',
  };

  String get label => switch (this) {
    BodySafetyCheckContext.routine => 'Contrôle régulier',
    BodySafetyCheckContext.beforeTrip => 'Avant un trajet',
    BodySafetyCheckContext.afterImpact => 'Après un choc ou un accrochage',
    BodySafetyCheckContext.beforeControlOrSale =>
      'Avant un contrôle ou une vente',
  };
}

enum BodySafetyCareStatus {
  notChecked,
  notApplicable,
  normal,
  monitor,
  action,
  urgent,
}

extension BodySafetyCareStatusX on BodySafetyCareStatus {
  String get databaseValue => switch (this) {
    BodySafetyCareStatus.notChecked => 'NOT_CHECKED',
    BodySafetyCareStatus.notApplicable => 'NOT_APPLICABLE',
    BodySafetyCareStatus.normal => 'NORMAL',
    BodySafetyCareStatus.monitor => 'MONITOR',
    BodySafetyCareStatus.action => 'ACTION',
    BodySafetyCareStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    BodySafetyCareStatus.notChecked => 'Non vérifié',
    BodySafetyCareStatus.notApplicable => 'Non applicable au véhicule',
    BodySafetyCareStatus.normal => 'État visuel habituel',
    BodySafetyCareStatus.monitor => 'À surveiller',
    BodySafetyCareStatus.action => 'Contrôle à prévoir',
    BodySafetyCareStatus.urgent => 'Avis professionnel prioritaire',
  };
}

enum BodySafetyCareLevel { ready, review, action, urgent }

extension BodySafetyCareLevelX on BodySafetyCareLevel {
  String get databaseValue => switch (this) {
    BodySafetyCareLevel.ready => 'READY',
    BodySafetyCareLevel.review => 'REVIEW',
    BodySafetyCareLevel.action => 'ACTION',
    BodySafetyCareLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    BodySafetyCareLevel.ready => 'Contrôle complété',
    BodySafetyCareLevel.review => 'Vérifications à terminer',
    BodySafetyCareLevel.action => 'Contrôle recommandé',
    BodySafetyCareLevel.urgent => 'Avis professionnel prioritaire',
  };
}

enum BodySafetyCareArea {
  doorsAndLocks,
  hoodClosure,
  trunkAndTailgate,
  seatBelts,
  seatsAndHeadRestraints,
  hornAndControls,
  platesAndReflectors,
  bodyFixingsAndSharpEdges,
  cabinAndCargoSecurity,
  professionalCheckPlan,
}

extension BodySafetyCareAreaX on BodySafetyCareArea {
  String get databaseValue => switch (this) {
    BodySafetyCareArea.doorsAndLocks => 'DOORS_AND_LOCKS',
    BodySafetyCareArea.hoodClosure => 'HOOD_CLOSURE',
    BodySafetyCareArea.trunkAndTailgate => 'TRUNK_AND_TAILGATE',
    BodySafetyCareArea.seatBelts => 'SEAT_BELTS',
    BodySafetyCareArea.seatsAndHeadRestraints => 'SEATS_AND_HEAD_RESTRAINTS',
    BodySafetyCareArea.hornAndControls => 'HORN_AND_CONTROLS',
    BodySafetyCareArea.platesAndReflectors => 'PLATES_AND_REFLECTORS',
    BodySafetyCareArea.bodyFixingsAndSharpEdges =>
      'BODY_FIXINGS_AND_SHARP_EDGES',
    BodySafetyCareArea.cabinAndCargoSecurity => 'CABIN_AND_CARGO_SECURITY',
    BodySafetyCareArea.professionalCheckPlan => 'PROFESSIONAL_CHECK_PLAN',
  };

  String get label => switch (this) {
    BodySafetyCareArea.doorsAndLocks => 'Portes, verrouillage et ouverture',
    BodySafetyCareArea.hoodClosure => 'Fermeture du capot',
    BodySafetyCareArea.trunkAndTailgate => 'Coffre, hayon ou portes arrière',
    BodySafetyCareArea.seatBelts => 'Ceintures et boucles accessibles',
    BodySafetyCareArea.seatsAndHeadRestraints => 'Sièges et appuie-têtes',
    BodySafetyCareArea.hornAndControls =>
      'Avertisseur et commandes essentielles',
    BodySafetyCareArea.platesAndReflectors =>
      'Plaques et éléments réfléchissants visibles',
    BodySafetyCareArea.bodyFixingsAndSharpEdges =>
      'Fixations, éléments saillants et dommages visibles',
    BodySafetyCareArea.cabinAndCargoSecurity =>
      'Objets et chargement dans l’habitacle',
    BodySafetyCareArea.professionalCheckPlan =>
      'Contrôle professionnel à prévoir',
  };

  bool get isSafetyCritical =>
      this == BodySafetyCareArea.doorsAndLocks ||
      this == BodySafetyCareArea.hoodClosure ||
      this == BodySafetyCareArea.trunkAndTailgate ||
      this == BodySafetyCareArea.seatBelts ||
      this == BodySafetyCareArea.seatsAndHeadRestraints ||
      this == BodySafetyCareArea.bodyFixingsAndSharpEdges ||
      this == BodySafetyCareArea.cabinAndCargoSecurity;
}

class BodySafetyCareProfile {
  const BodySafetyCareProfile({
    required this.vehicleId,
    required this.checkedAt,
    required this.checkContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.closureConcern,
    required this.restraintConcern,
    required this.recentImpact,
  });

  final String vehicleId;
  final DateTime checkedAt;
  final BodySafetyCheckContext checkContext;
  final Map<BodySafetyCareArea, BodySafetyCareStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool closureConcern;
  final bool restraintConcern;
  final bool recentImpact;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in BodySafetyCareArea.values) {
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
    'closure_concern': closureConcern,
    'restraint_concern': restraintConcern,
    'recent_impact': recentImpact,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class BodySafetyCareFinding {
  const BodySafetyCareFinding({
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

class BodySafetyCareAssessment {
  const BodySafetyCareAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final BodySafetyCareLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<BodySafetyCareFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required BodySafetyCareProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — CARROSSERIE, OUVRANTS ET SÉCURITÉ')
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
        'Ce résumé reprend uniquement des observations visuelles déclarées. '
        'Il ne constitue ni une expertise structurelle ni une certification de '
        'conformité et ne garantit pas la sécurité du véhicule. Un professionnel '
        'et la notice du véhicule restent les références.',
      );
    return buffer.toString().trim();
  }
}

class BodySafetyCareSnapshot {
  const BodySafetyCareSnapshot({
    required this.id,
    required this.checkedAt,
    required this.checkContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime checkedAt;
  final BodySafetyCheckContext checkContext;
  final BodySafetyCareLevel level;
  final int score;
  final int completenessPercent;

  factory BodySafetyCareSnapshot.fromMap(Map<String, dynamic> map) {
    return BodySafetyCareSnapshot(
      id: map['id']?.toString() ?? '',
      checkedAt: DateTime.parse(map['checked_at'].toString()),
      checkContext: bodySafetyCheckContextFromDatabase(
        map['check_context']?.toString(),
      ),
      level: bodySafetyCareLevelFromDatabase(map['care_level']?.toString()),
      score: (map['care_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

BodySafetyCheckContext bodySafetyCheckContextFromDatabase(String? value) =>
    switch (value) {
      'BEFORE_TRIP' => BodySafetyCheckContext.beforeTrip,
      'AFTER_IMPACT' => BodySafetyCheckContext.afterImpact,
      'BEFORE_CONTROL_OR_SALE' => BodySafetyCheckContext.beforeControlOrSale,
      _ => BodySafetyCheckContext.routine,
    };

BodySafetyCareLevel bodySafetyCareLevelFromDatabase(String? value) =>
    switch (value) {
      'REVIEW' => BodySafetyCareLevel.review,
      'ACTION' => BodySafetyCareLevel.action,
      'URGENT' => BodySafetyCareLevel.urgent,
      _ => BodySafetyCareLevel.ready,
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
