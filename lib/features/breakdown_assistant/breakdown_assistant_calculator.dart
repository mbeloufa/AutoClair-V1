import 'breakdown_assistant_models.dart';

class BreakdownAssistantCalculator {
  BreakdownAssistantCalculator._();

  static BreakdownAssessment assess(BreakdownAssessmentInput input) {
    final symptoms = input.symptoms;
    final hasFire = symptoms.contains(BreakdownSymptom.smokeOrFire);
    final immediateEmergency = input.injuredPerson || hasFire;
    if (immediateEmergency) {
      return _assessment(
        input: input,
        actionLevel: BreakdownActionLevel.emergency,
        title: 'Éloignez-vous et appelez les secours',
        explanation: input.injuredPerson
            ? 'Une personne est blessée. La sécurité humaine passe avant le véhicule.'
            : 'La fumée, l’odeur de brûlé ou le feu imposent une évacuation immédiate.',
        shouldCall112: true,
        shouldCallAssistance: true,
        mayDrive: false,
      );
    }

    final exposedOnMotorway =
        input.locationType == BreakdownLocationType.motorway &&
        (!input.safelyParked || input.vehicleInTrafficLane);
    if (exposedOnMotorway) {
      return _assessment(
        input: input,
        actionLevel: BreakdownActionLevel.motorwaySafety,
        title: 'Mettez tous les occupants à l’abri',
        explanation:
            'Sur autoroute, la priorité est de quitter le véhicule côté passager et de se placer derrière la glissière.',
        shouldCall112: input.vehicleInTrafficLane,
        shouldCallAssistance: true,
        mayDrive: false,
      );
    }

    final criticalSymptoms = <BreakdownSymptom>{
      BreakdownSymptom.redWarningLight,
      BreakdownSymptom.overheating,
      BreakdownSymptom.fluidLeak,
      BreakdownSymptom.brakeIssue,
      BreakdownSymptom.steeringIssue,
      BreakdownSymptom.highVoltageWarning,
      BreakdownSymptom.lossOfPower,
    };
    if (symptoms.any(criticalSymptoms.contains)) {
      return _assessment(
        input: input,
        actionLevel: BreakdownActionLevel.stopAndAssistance,
        title: 'Coupez le véhicule et demandez une assistance',
        explanation:
            'Les symptômes sélectionnés peuvent compromettre la sécurité ou aggraver une panne. Ne reprenez pas la route.',
        shouldCall112: false,
        shouldCallAssistance: true,
        mayDrive: false,
      );
    }

    final assistanceSymptoms = <BreakdownSymptom>{
      BreakdownSymptom.tyreDamage,
      BreakdownSymptom.noStart,
      BreakdownSymptom.electricalIssue,
    };
    if (symptoms.any(assistanceSymptoms.contains) || !input.vehicleCanMove) {
      return _assessment(
        input: input,
        actionLevel: BreakdownActionLevel.assistanceRecommended,
        title: 'Contactez votre assistance',
        explanation:
            'Le véhicule ne doit pas être déplacé sans vérification ou ne peut pas repartir dans de bonnes conditions.',
        shouldCall112: false,
        shouldCallAssistance: true,
        mayDrive: false,
      );
    }

    if (symptoms.contains(BreakdownSymptom.unusualNoise) ||
        symptoms.contains(BreakdownSymptom.strongVibration)) {
      return _assessment(
        input: input,
        actionLevel: BreakdownActionLevel.garageSoon,
        title: 'Faites contrôler le véhicule rapidement',
        explanation:
            'Aucun signal critique n’est déclaré, mais le bruit ou les vibrations doivent être contrôlés sans attendre.',
        shouldCall112: false,
        shouldCallAssistance: false,
        mayDrive: input.safelyParked && input.vehicleCanMove,
      );
    }

    return _assessment(
      input: input,
      actionLevel: BreakdownActionLevel.monitor,
      title: 'Complétez les symptômes et restez vigilant',
      explanation: symptoms.isEmpty
          ? 'Aucun symptôme mécanique n’est encore sélectionné.'
          : 'Les éléments déclarés ne signalent pas une urgence immédiate, mais une vérification reste recommandée.',
      shouldCall112: false,
      shouldCallAssistance: false,
      mayDrive: input.safelyParked && input.vehicleCanMove,
    );
  }

  static BreakdownAssessment _assessment({
    required BreakdownAssessmentInput input,
    required BreakdownActionLevel actionLevel,
    required String title,
    required String explanation,
    required bool shouldCall112,
    required bool shouldCallAssistance,
    required bool mayDrive,
  }) {
    final classification = _classification(input.symptoms);
    return BreakdownAssessment(
      actionLevel: actionLevel,
      title: title,
      explanation: explanation,
      immediateSteps: _immediateSteps(input, actionLevel),
      safeChecks: _safeChecks(input.symptoms),
      thingsToAvoid: _thingsToAvoid(input, actionLevel),
      shouldCall112: shouldCall112,
      shouldCallAssistance: shouldCallAssistance,
      mayDrive: mayDrive,
      eventType: classification.eventType,
      categoryCode: classification.categoryCode,
      subcategoryCode: classification.subcategoryCode,
      symptomCodes:
          input.symptoms.map((symptom) => symptom.code).toList(growable: false)
            ..sort(),
    );
  }

  static List<String> _immediateSteps(
    BreakdownAssessmentInput input,
    BreakdownActionLevel level,
  ) {
    final steps = <String>['Allumez les feux de détresse.'];
    switch (input.locationType) {
      case BreakdownLocationType.motorway:
        steps.addAll(const [
          'Rangez-vous le plus à droite possible uniquement si la manœuvre reste sûre.',
          'Enfilez le gilet avant de sortir et faites sortir tout le monde côté passager.',
          'Placez-vous derrière la glissière et utilisez la borne orange la plus proche.',
          'Si la borne est inaccessible ou qu’une voie reste occupée, appelez le 112.',
        ]);
      case BreakdownLocationType.road:
        steps.addAll(const [
          'Immobilisez le véhicule hors de la circulation si cela reste possible sans danger.',
          'Enfilez le gilet avant de sortir et éloignez les passagers du trafic.',
        ]);
      case BreakdownLocationType.safeParking:
        steps.addAll(const [
          'Serrez le frein de stationnement et coupez le moteur ou le système de traction.',
          'Gardez les passagers dans un endroit protégé de la circulation.',
        ]);
    }
    if (level == BreakdownActionLevel.emergency) {
      steps.add('Éloignez-vous du véhicule et appelez immédiatement le 112.');
    }
    return List.unmodifiable(steps);
  }

  static List<String> _safeChecks(Set<BreakdownSymptom> symptoms) {
    final checks = <String>[
      'Notez le message exact affiché au tableau de bord et la couleur du voyant.',
      'Prenez une photo seulement depuis un endroit sûr.',
    ];
    if (symptoms.contains(BreakdownSymptom.noStart) ||
        symptoms.contains(BreakdownSymptom.electricalIssue)) {
      checks.addAll(const [
        'Vérifiez que la boîte est sur P ou N, ou que l’embrayage est enfoncé.',
        'Observez si les éclairages et le tableau de bord s’allument normalement.',
      ]);
    }
    if (symptoms.contains(BreakdownSymptom.tyreDamage)) {
      checks.add(
        'Observez le pneu à distance sûre sans vous placer côté circulation.',
      );
    }
    if (symptoms.contains(BreakdownSymptom.overheating)) {
      checks.add(
        'Laissez refroidir le véhicule sans ouvrir le circuit de refroidissement.',
      );
    }
    if (symptoms.contains(BreakdownSymptom.highVoltageWarning)) {
      checks.add(
        'Éloignez-vous des câbles orange et de toute zone humide sous le véhicule.',
      );
    }
    return List.unmodifiable(checks);
  }

  static List<String> _thingsToAvoid(
    BreakdownAssessmentInput input,
    BreakdownActionLevel level,
  ) {
    final avoid = <String>[
      'Ne vous placez jamais entre le véhicule et la circulation.',
      'Ne touchez pas une fuite, une pièce chaude ou un câble électrique orange.',
      'Ne multipliez pas les tentatives de démarrage.',
    ];
    if (input.locationType == BreakdownLocationType.motorway) {
      avoid.add(
        'N’installez pas le triangle sur autoroute et ne traversez jamais les voies.',
      );
    }
    if (level == BreakdownActionLevel.emergency) {
      avoid.add('N’ouvrez pas le capot en présence de fumée ou de feu.');
    }
    if (!input.safelyParked || input.vehicleInTrafficLane) {
      avoid.add('Ne restez pas dans le véhicule exposé à la circulation.');
    }
    return List.unmodifiable(avoid);
  }

  static _BreakdownClassification _classification(
    Set<BreakdownSymptom> symptoms,
  ) {
    if (symptoms.contains(BreakdownSymptom.tyreDamage)) {
      return const _BreakdownClassification(
        eventType: 'TYRES',
        categoryCode: 'SAFETY',
        subcategoryCode: 'TYRES',
      );
    }
    if (symptoms.contains(BreakdownSymptom.brakeIssue)) {
      return const _BreakdownClassification(
        eventType: 'REPAIR',
        categoryCode: 'SAFETY',
        subcategoryCode: 'BRAKES',
      );
    }
    if (symptoms.contains(BreakdownSymptom.steeringIssue)) {
      return const _BreakdownClassification(
        eventType: 'REPAIR',
        categoryCode: 'REPAIR',
        subcategoryCode: 'STEERING_SUSPENSION',
      );
    }
    if (symptoms.contains(BreakdownSymptom.noStart) ||
        symptoms.contains(BreakdownSymptom.electricalIssue) ||
        symptoms.contains(BreakdownSymptom.highVoltageWarning)) {
      return const _BreakdownClassification(
        eventType: 'REPAIR',
        categoryCode: 'REPAIR',
        subcategoryCode: 'BATTERY_ELECTRICAL',
      );
    }
    if (symptoms.contains(BreakdownSymptom.overheating) ||
        symptoms.contains(BreakdownSymptom.lossOfPower) ||
        symptoms.contains(BreakdownSymptom.smokeOrFire)) {
      return const _BreakdownClassification(
        eventType: 'REPAIR',
        categoryCode: 'REPAIR',
        subcategoryCode: 'ENGINE_TRANSMISSION',
      );
    }
    return const _BreakdownClassification(
      eventType: 'REPAIR',
      categoryCode: 'REPAIR',
      subcategoryCode: 'DIAGNOSTICS',
    );
  }
}

class _BreakdownClassification {
  const _BreakdownClassification({
    required this.eventType,
    required this.categoryCode,
    required this.subcategoryCode,
  });

  final String eventType;
  final String categoryCode;
  final String subcategoryCode;
}
