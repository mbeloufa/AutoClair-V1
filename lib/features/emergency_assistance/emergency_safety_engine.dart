enum EmergencyCategory {
  warningLight,
  noiseBehavior,
  immobilized,
  lockedOut,
  smokeSmellLeak,
  tireProblem,
  powerLoss,
  other,
}

extension EmergencyCategoryX on EmergencyCategory {
  String get dbValue => switch (this) {
    EmergencyCategory.warningLight => 'warning_light',
    EmergencyCategory.noiseBehavior => 'noise_behavior',
    EmergencyCategory.immobilized => 'immobilized',
    EmergencyCategory.lockedOut => 'locked_out',
    EmergencyCategory.smokeSmellLeak => 'smoke_smell_leak',
    EmergencyCategory.tireProblem => 'tire_problem',
    EmergencyCategory.powerLoss => 'power_loss',
    EmergencyCategory.other => 'other',
  };

  String get label => switch (this) {
    EmergencyCategory.warningLight => 'Un voyant ou un message',
    EmergencyCategory.noiseBehavior => 'Un bruit ou un comportement inhabituel',
    EmergencyCategory.immobilized => 'Ma voiture est immobilisée',
    EmergencyCategory.lockedOut => 'Je n’arrive pas à ouvrir la voiture',
    EmergencyCategory.smokeSmellLeak => 'Fumée, odeur ou fuite',
    EmergencyCategory.tireProblem => 'Un problème de pneu',
    EmergencyCategory.powerLoss => 'Perte de puissance',
    EmergencyCategory.other => 'Autre problème',
  };

  String get description => switch (this) {
    EmergencyCategory.warningLight =>
      'Photo du tableau de bord et quelques vérifications ciblées.',
    EmergencyCategory.noiseBehavior =>
      'Décrivez le comportement et, si utile, conservez un son pour le garage.',
    EmergencyCategory.immobilized =>
      'Démarrage impossible, batterie, clé ou véhicule bloqué.',
    EmergencyCategory.lockedOut =>
      'Télécommande, clé ou véhicule qui semble hors tension.',
    EmergencyCategory.smokeSmellLeak =>
      'Priorité à la mise en sécurité avant toute analyse.',
    EmergencyCategory.tireProblem =>
      'Crevaison, déformation, perte de pression ou dommage visible.',
    EmergencyCategory.powerLoss =>
      'Perte de puissance ou comportement moteur fortement dégradé.',
    EmergencyCategory.other =>
      'AutoClair vérifie d’abord les éléments de sécurité.',
  };
}

enum EmergencySafetyLevel { stop, assistance, promptCheck, monitor }

extension EmergencySafetyLevelX on EmergencySafetyLevel {
  String get dbValue => switch (this) {
    EmergencySafetyLevel.stop => 'stop',
    EmergencySafetyLevel.assistance => 'assistance',
    EmergencySafetyLevel.promptCheck => 'prompt_check',
    EmergencySafetyLevel.monitor => 'monitor',
  };

  String get label => switch (this) {
    EmergencySafetyLevel.stop => 'Ne repartez pas',
    EmergencySafetyLevel.assistance => 'Assistance recommandée',
    EmergencySafetyLevel.promptCheck => 'Contrôle recommandé rapidement',
    EmergencySafetyLevel.monitor => 'Surveillance',
  };

  int get rank => switch (this) {
    EmergencySafetyLevel.stop => 3,
    EmergencySafetyLevel.assistance => 2,
    EmergencySafetyLevel.promptCheck => 1,
    EmergencySafetyLevel.monitor => 0,
  };

  static EmergencySafetyLevel fromDbValue(String value) => switch (value) {
    'stop' => EmergencySafetyLevel.stop,
    'assistance' => EmergencySafetyLevel.assistance,
    'monitor' => EmergencySafetyLevel.monitor,
    _ => EmergencySafetyLevel.promptCheck,
  };
}

class EmergencySafetyFlags {
  const EmergencySafetyFlags({
    this.injury = false,
    this.fireOrHeavySmoke = false,
    this.fuelSmellOrLeak = false,
    this.brakeLoss = false,
    this.steeringLoss = false,
    this.overheat = false,
    this.stopMessage = false,
    this.highVoltageDamage = false,
    this.vehicleInTrafficLane = false,
    this.severeTireDamage = false,
    this.redWarning = false,
    this.flashingWarning = false,
    this.lossOfPower = false,
    this.abnormalBrakingNoise = false,
  });

  final bool injury;
  final bool fireOrHeavySmoke;
  final bool fuelSmellOrLeak;
  final bool brakeLoss;
  final bool steeringLoss;
  final bool overheat;
  final bool stopMessage;
  final bool highVoltageDamage;
  final bool vehicleInTrafficLane;
  final bool severeTireDamage;
  final bool redWarning;
  final bool flashingWarning;
  final bool lossOfPower;
  final bool abnormalBrakingNoise;

  Map<String, dynamic> toMap() => {
    'injury': injury,
    'fire_or_heavy_smoke': fireOrHeavySmoke,
    'fuel_smell_or_leak': fuelSmellOrLeak,
    'brake_loss': brakeLoss,
    'steering_loss': steeringLoss,
    'overheat': overheat,
    'stop_message': stopMessage,
    'high_voltage_damage': highVoltageDamage,
    'vehicle_in_traffic_lane': vehicleInTrafficLane,
    'severe_tire_damage': severeTireDamage,
    'red_warning': redWarning,
    'flashing_warning': flashingWarning,
    'loss_of_power': lossOfPower,
    'abnormal_braking_noise': abnormalBrakingNoise,
  };
}

class EmergencySafetyDecision {
  const EmergencySafetyDecision({
    required this.level,
    required this.title,
    required this.reasons,
    required this.actions,
    required this.callEmergencyServices,
  });

  final EmergencySafetyLevel level;
  final String title;
  final List<String> reasons;
  final List<String> actions;
  final bool callEmergencyServices;

  static EmergencySafetyDecision evaluate({
    required EmergencyCategory category,
    required EmergencySafetyFlags flags,
  }) {
    final stopReasons = <String>[];
    var callEmergencyServices = false;

    if (flags.injury) {
      stopReasons.add(
        'Une personne est blessée ou pourrait nécessiter des secours.',
      );
      callEmergencyServices = true;
    }
    if (flags.fireOrHeavySmoke) {
      stopReasons.add('Un feu ou une fumée importante a été signalé.');
      callEmergencyServices = true;
    }
    if (flags.vehicleInTrafficLane) {
      stopReasons.add(
        'Le véhicule est immobilisé dans une zone exposée à la circulation.',
      );
    }
    if (flags.fuelSmellOrLeak) {
      stopReasons.add(
        'Une forte odeur ou une fuite de carburant est signalée.',
      );
    }
    if (flags.brakeLoss) {
      stopReasons.add('Le freinage est décrit comme fortement dégradé.');
    }
    if (flags.steeringLoss) {
      stopReasons.add('La direction est décrite comme fortement dégradée.');
    }
    if (flags.overheat) {
      stopReasons.add('Une surchauffe moteur est signalée.');
    }
    if (flags.stopMessage) {
      stopReasons.add('Le véhicule affiche un message explicite STOP.');
    }
    if (flags.highVoltageDamage) {
      stopReasons.add(
        'Un dommage potentiel du système haute tension est signalé.',
      );
    }
    if (flags.severeTireDamage) {
      stopReasons.add('Un dommage important du pneu est signalé.');
    }

    if (stopReasons.isNotEmpty) {
      return EmergencySafetyDecision(
        level: EmergencySafetyLevel.stop,
        title: 'Ne repartez pas',
        reasons: stopReasons,
        actions: [
          'Mettez-vous à l’écart de la circulation si cela peut être fait sans danger.',
          'N’effectuez aucune réparation risquée sur place.',
          if (callEmergencyServices)
            'Contactez les secours si une personne est blessée ou si un danger immédiat persiste.'
          else
            'Contactez une assistance pour faire contrôler ou déplacer le véhicule.',
        ],
        callEmergencyServices: callEmergencyServices,
      );
    }

    if (category == EmergencyCategory.immobilized ||
        category == EmergencyCategory.lockedOut ||
        flags.redWarning ||
        (flags.flashingWarning && flags.lossOfPower)) {
      return const EmergencySafetyDecision(
        level: EmergencySafetyLevel.assistance,
        title: 'Assistance recommandée',
        reasons: [
          'La situation peut nécessiter une prise en charge avant de reprendre normalement la route.',
        ],
        actions: [
          'Restez dans un endroit sûr.',
          'Utilisez les informations de votre assistance si le problème persiste.',
        ],
        callEmergencyServices: false,
      );
    }

    if (flags.lossOfPower ||
        flags.abnormalBrakingNoise ||
        category == EmergencyCategory.smokeSmellLeak ||
        category == EmergencyCategory.tireProblem ||
        category == EmergencyCategory.powerLoss ||
        category == EmergencyCategory.noiseBehavior ||
        category == EmergencyCategory.warningLight) {
      return const EmergencySafetyDecision(
        level: EmergencySafetyLevel.promptCheck,
        title: 'Contrôle recommandé rapidement',
        reasons: [
          'Aucun critère d’arrêt immédiat n’est établi, mais le symptôme mérite un contrôle.',
        ],
        actions: [
          'Surveillez toute aggravation.',
          'Si un nouveau signe critique apparaît, arrêtez-vous et demandez une assistance.',
        ],
        callEmergencyServices: false,
      );
    }

    return const EmergencySafetyDecision(
      level: EmergencySafetyLevel.monitor,
      title: 'Surveillance',
      reasons: [
        'Aucun signe critique n’est identifié avec les informations saisies.',
      ],
      actions: ['Restez attentif à l’évolution du comportement du véhicule.'],
      callEmergencyServices: false,
    );
  }
}
