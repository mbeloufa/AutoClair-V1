enum BreakdownLocationType { motorway, road, safeParking }

extension BreakdownLocationTypeX on BreakdownLocationType {
  String get databaseValue => switch (this) {
    BreakdownLocationType.motorway => 'MOTORWAY',
    BreakdownLocationType.road => 'ROAD',
    BreakdownLocationType.safeParking => 'SAFE_PARKING',
  };

  String get label => switch (this) {
    BreakdownLocationType.motorway => 'Autoroute ou voie rapide',
    BreakdownLocationType.road => 'Route ou rue',
    BreakdownLocationType.safeParking => 'Stationnement sécurisé',
  };
}

enum BreakdownSymptom {
  redWarningLight,
  overheating,
  smokeOrFire,
  fluidLeak,
  tyreDamage,
  brakeIssue,
  steeringIssue,
  noStart,
  electricalIssue,
  highVoltageWarning,
  lossOfPower,
  unusualNoise,
  strongVibration,
}

extension BreakdownSymptomX on BreakdownSymptom {
  String get code => switch (this) {
    BreakdownSymptom.redWarningLight => 'RED_WARNING_LIGHT',
    BreakdownSymptom.overheating => 'OVERHEATING',
    BreakdownSymptom.smokeOrFire => 'SMOKE_OR_FIRE',
    BreakdownSymptom.fluidLeak => 'FLUID_LEAK',
    BreakdownSymptom.tyreDamage => 'TYRE_DAMAGE',
    BreakdownSymptom.brakeIssue => 'BRAKE_ISSUE',
    BreakdownSymptom.steeringIssue => 'STEERING_ISSUE',
    BreakdownSymptom.noStart => 'NO_START',
    BreakdownSymptom.electricalIssue => 'ELECTRICAL_ISSUE',
    BreakdownSymptom.highVoltageWarning => 'HIGH_VOLTAGE_WARNING',
    BreakdownSymptom.lossOfPower => 'LOSS_OF_POWER',
    BreakdownSymptom.unusualNoise => 'UNUSUAL_NOISE',
    BreakdownSymptom.strongVibration => 'STRONG_VIBRATION',
  };

  String get label => switch (this) {
    BreakdownSymptom.redWarningLight => 'Voyant rouge ou message STOP',
    BreakdownSymptom.overheating => 'Température moteur anormale',
    BreakdownSymptom.smokeOrFire => 'Fumée, odeur de brûlé ou départ de feu',
    BreakdownSymptom.fluidLeak => 'Fuite importante sous le véhicule',
    BreakdownSymptom.tyreDamage => 'Pneu crevé ou visiblement endommagé',
    BreakdownSymptom.brakeIssue => 'Freinage anormal ou inefficace',
    BreakdownSymptom.steeringIssue => 'Direction très dure ou instable',
    BreakdownSymptom.noStart => 'Le véhicule ne démarre pas',
    BreakdownSymptom.electricalIssue => 'Batterie ou problème électrique',
    BreakdownSymptom.highVoltageWarning => 'Alerte haute tension électrique',
    BreakdownSymptom.lossOfPower => 'Perte de puissance importante',
    BreakdownSymptom.unusualNoise => 'Bruit inhabituel',
    BreakdownSymptom.strongVibration => 'Vibrations fortes',
  };
}

enum BreakdownActionLevel {
  emergency,
  motorwaySafety,
  stopAndAssistance,
  assistanceRecommended,
  garageSoon,
  monitor,
}

extension BreakdownActionLevelX on BreakdownActionLevel {
  String get databaseValue => switch (this) {
    BreakdownActionLevel.emergency => 'EMERGENCY',
    BreakdownActionLevel.motorwaySafety => 'MOTORWAY_SAFETY',
    BreakdownActionLevel.stopAndAssistance => 'STOP_AND_ASSISTANCE',
    BreakdownActionLevel.assistanceRecommended => 'ASSISTANCE_RECOMMENDED',
    BreakdownActionLevel.garageSoon => 'GARAGE_SOON',
    BreakdownActionLevel.monitor => 'MONITOR',
  };

  String get label => switch (this) {
    BreakdownActionLevel.emergency => 'Urgence immédiate',
    BreakdownActionLevel.motorwaySafety => 'Mise à l’abri prioritaire',
    BreakdownActionLevel.stopAndAssistance => 'Ne reprenez pas la route',
    BreakdownActionLevel.assistanceRecommended => 'Assistance recommandée',
    BreakdownActionLevel.garageSoon => 'Contrôle rapide au garage',
    BreakdownActionLevel.monitor => 'Surveillance et vérification',
  };
}

class BreakdownAssistantProfile {
  const BreakdownAssistantProfile({
    this.assistanceProvider,
    this.assistancePhone,
    this.contractReference,
    this.assistanceZeroKm,
  });

  final String? assistanceProvider;
  final String? assistancePhone;
  final String? contractReference;
  final bool? assistanceZeroKm;

  factory BreakdownAssistantProfile.fromMap(Map<String, dynamic> map) {
    return BreakdownAssistantProfile(
      assistanceProvider: _nullableText(map['assistance_provider']),
      assistancePhone: _nullableText(map['assistance_phone']),
      contractReference: _nullableText(map['contract_reference']),
      assistanceZeroKm: map['assistance_zero_km'] as bool?,
    );
  }

  void validate() {
    final phone = assistancePhone?.trim();
    if (phone != null && phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 6 || digits.length > 15) {
        throw const FormatException(
          'Le numéro d’assistance doit contenir entre 6 et 15 chiffres.',
        );
      }
    }
    if ((contractReference?.length ?? 0) > 80) {
      throw const FormatException(
        'La référence de contrat ne doit pas dépasser 80 caractères.',
      );
    }
  }

  String? get callablePhone {
    final raw = assistancePhone?.trim();
    if (raw == null || raw.isEmpty) return null;
    final plus = raw.startsWith('+') ? '+' : '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : '$plus$digits';
  }
}

class BreakdownAssessmentInput {
  const BreakdownAssessmentInput({
    required this.locationType,
    required this.symptoms,
    required this.safelyParked,
    required this.vehicleInTrafficLane,
    required this.injuredPerson,
    required this.vehicleCanMove,
  });

  final BreakdownLocationType locationType;
  final Set<BreakdownSymptom> symptoms;
  final bool safelyParked;
  final bool vehicleInTrafficLane;
  final bool injuredPerson;
  final bool vehicleCanMove;
}

class BreakdownAssessment {
  const BreakdownAssessment({
    required this.actionLevel,
    required this.title,
    required this.explanation,
    required this.immediateSteps,
    required this.safeChecks,
    required this.thingsToAvoid,
    required this.shouldCall112,
    required this.shouldCallAssistance,
    required this.mayDrive,
    required this.eventType,
    required this.categoryCode,
    required this.subcategoryCode,
    required this.symptomCodes,
  });

  final BreakdownActionLevel actionLevel;
  final String title;
  final String explanation;
  final List<String> immediateSteps;
  final List<String> safeChecks;
  final List<String> thingsToAvoid;
  final bool shouldCall112;
  final bool shouldCallAssistance;
  final bool mayDrive;
  final String eventType;
  final String categoryCode;
  final String subcategoryCode;
  final List<String> symptomCodes;

  String buildShareSummary({
    required String vehicleName,
    required BreakdownAssessmentInput input,
    String? notes,
    int? mileage,
  }) {
    final symptomLabels =
        input.symptoms.map((symptom) => symptom.label).toList(growable: false)
          ..sort();
    final buffer = StringBuffer()
      ..writeln('ASSISTANT PANNE AUTOCLAIR')
      ..writeln('Véhicule : $vehicleName')
      ..writeln('Situation : ${input.locationType.label}')
      ..writeln('Niveau d’action : ${actionLevel.label}');
    if (mileage != null) buffer.writeln('Kilométrage : $mileage km');
    buffer
      ..writeln('Véhicule en sécurité : ${input.safelyParked ? 'oui' : 'non'}')
      ..writeln(
        'Véhicule sur une voie de circulation : '
        '${input.vehicleInTrafficLane ? 'oui' : 'non'}',
      )
      ..writeln('Personne blessée : ${input.injuredPerson ? 'oui' : 'non'}')
      ..writeln(
        'Déplacement encore possible : ${input.vehicleCanMove ? 'oui' : 'non'}',
      )
      ..writeln(
        'Symptômes : ${symptomLabels.isEmpty ? 'non précisés' : symptomLabels.join(', ')}',
      )
      ..writeln('Orientation : $explanation');
    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      buffer.writeln('Observations : $trimmedNotes');
    }
    buffer.writeln(
      'Ce résumé décrit les faits saisis. Il ne constitue pas un diagnostic mécanique.',
    );
    return buffer.toString().trim();
  }
}

class BreakdownCaseSummary {
  const BreakdownCaseSummary({
    required this.id,
    required this.occurredAt,
    required this.actionLevel,
    required this.locationType,
    required this.symptomCodes,
    required this.summary,
  });

  final String id;
  final DateTime occurredAt;
  final String actionLevel;
  final String locationType;
  final List<String> symptomCodes;
  final String summary;

  factory BreakdownCaseSummary.fromMap(Map<String, dynamic> map) {
    final rawSymptoms = map['symptom_codes'];
    return BreakdownCaseSummary(
      id: map['id']?.toString() ?? '',
      occurredAt:
          DateTime.tryParse(map['occurred_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      actionLevel: map['action_level']?.toString() ?? 'MONITOR',
      locationType: map['location_type']?.toString() ?? 'SAFE_PARKING',
      symptomCodes: rawSymptoms is List
          ? rawSymptoms.map((value) => value.toString()).toList(growable: false)
          : const [],
      summary: map['summary']?.toString() ?? '',
    );
  }
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
