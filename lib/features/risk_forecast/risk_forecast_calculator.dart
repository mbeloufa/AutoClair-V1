import 'risk_forecast_models.dart';

class RiskForecastCalculator {
  const RiskForecastCalculator._();

  static RiskForecastAssessment assess(
    RiskForecastProfile profile, {
    DateTime? generatedAt,
  }) {
    profile.validate();
    final factors = <RiskForecastFactor>[];

    _addSafetyFactors(profile, factors);
    _addMaintenanceFactors(profile, factors);
    _addAgeAndMileageFactors(profile, factors);
    _addUsageFactors(profile, factors);
    _addReliabilityFactors(profile, factors);

    final rawScore = factors.fold<int>(0, (sum, factor) => sum + factor.points);
    final score = rawScore < 0
        ? 0
        : rawScore > 100
        ? 100
        : rawScore;
    final hasSafetyCritical = factors.any((factor) => factor.safetyCritical);
    final level = hasSafetyCritical || score >= 70
        ? RiskForecastLevel.priority
        : score >= 45
        ? RiskForecastLevel.elevated
        : score >= 20
        ? RiskForecastLevel.watch
        : RiskForecastLevel.low;

    final completedSignals = profile.completedSignalCount;
    final confidence = completedSignals >= 10
        ? RiskForecastConfidence.strong
        : completedSignals >= 8
        ? RiskForecastConfidence.medium
        : RiskForecastConfidence.limited;

    return RiskForecastAssessment(
      score: score,
      level: level,
      dataConfidence: confidence,
      factors: List.unmodifiable(factors),
      generatedAt: generatedAt ?? DateTime.now(),
    );
  }

  static void _addSafetyFactors(
    RiskForecastProfile profile,
    List<RiskForecastFactor> factors,
  ) {
    if (profile.brakingConcern) {
      factors.add(
        const RiskForecastFactor(
          code: 'BRAKING_SIGNAL',
          category: RiskForecastCategory.safety,
          title: 'Freinage à contrôler',
          detail:
              'Une sensation, un bruit ou une efficacité inhabituelle au freinage a été signalé.',
          action:
              'Évitez de prolonger l’usage et faites contrôler le freinage par un professionnel.',
          points: 35,
          horizon: RiskForecastHorizon.immediate,
          confidence: RiskForecastConfidence.strong,
          safetyCritical: true,
        ),
      );
    }

    if (profile.tireConcern) {
      factors.add(
        const RiskForecastFactor(
          code: 'TIRE_SIGNAL',
          category: RiskForecastCategory.safety,
          title: 'Pneumatiques à vérifier',
          detail:
              'Une usure, une perte de pression ou un comportement inhabituel a été déclaré.',
          action:
              'Contrôlez pression et état des pneus avant un trajet important.',
          points: 25,
          horizon: RiskForecastHorizon.immediate,
          confidence: RiskForecastConfidence.strong,
          safetyCritical: true,
        ),
      );
    }

    if (profile.engineCoolingConcern) {
      factors.add(
        const RiskForecastFactor(
          code: 'ENGINE_COOLING_SIGNAL',
          category: RiskForecastCategory.engineCooling,
          title: 'Moteur ou refroidissement à contrôler',
          detail:
              'Une surchauffe, une odeur, une fumée ou une anomalie de température a été déclarée.',
          action:
              'Arrêtez-vous en sécurité si le signal est présent et demandez un contrôle professionnel.',
          points: 30,
          horizon: RiskForecastHorizon.immediate,
          confidence: RiskForecastConfidence.strong,
          safetyCritical: true,
        ),
      );
    }

    if (profile.dashboardWarning) {
      factors.add(
        const RiskForecastFactor(
          code: 'DASHBOARD_WARNING',
          category: RiskForecastCategory.safety,
          title: 'Voyant ou message d’anomalie',
          detail:
              'Le tableau de bord signale une anomalie dont la gravité ne peut pas être déterminée par AutoClair.',
          action:
              'Consultez le manuel et faites identifier le signal. Un voyant rouge impose généralement un arrêt en sécurité.',
          points: 25,
          horizon: RiskForecastHorizon.immediate,
          confidence: RiskForecastConfidence.strong,
          safetyCritical: true,
        ),
      );
    }
  }

  static void _addMaintenanceFactors(
    RiskForecastProfile profile,
    List<RiskForecastFactor> factors,
  ) {
    var points = 0;
    if (profile.monthsSinceService >= 24) {
      points += 22;
    } else if (profile.monthsSinceService >= 18) {
      points += 16;
    } else if (profile.monthsSinceService >= 13) {
      points += 10;
    }

    if (profile.kmSinceService >= 25000) {
      points += 18;
    } else if (profile.kmSinceService >= 15000) {
      points += 10;
    }

    if (points == 0) return;
    final adjustedPoints = profile.maintenancePlanned
        ? (points * 0.65).round()
        : points;
    factors.add(
      RiskForecastFactor(
        code: 'MAINTENANCE_GAP',
        category: RiskForecastCategory.maintenance,
        title: 'Entretien à rapprocher',
        detail:
            '${profile.monthsSinceService} mois et ${profile.kmSinceService} km sont déclarés depuis le dernier entretien.',
        action: profile.maintenancePlanned
            ? 'Conservez le rendez-vous prévu et vérifiez les opérations recommandées pour le véhicule.'
            : 'Consultez le plan d’entretien et programmez un contrôle adapté au véhicule.',
        points: adjustedPoints,
        horizon: adjustedPoints >= 20
            ? RiskForecastHorizon.thirtyDays
            : RiskForecastHorizon.ninetyDays,
        confidence: RiskForecastConfidence.strong,
        safetyCritical: false,
      ),
    );
  }

  static void _addAgeAndMileageFactors(
    RiskForecastProfile profile,
    List<RiskForecastFactor> factors,
  ) {
    var agePoints = 0;
    if (profile.vehicleAgeYears >= 15) {
      agePoints = 12;
    } else if (profile.vehicleAgeYears >= 10) {
      agePoints = 8;
    } else if (profile.vehicleAgeYears >= 7) {
      agePoints = 4;
    }
    if (agePoints > 0) {
      factors.add(
        RiskForecastFactor(
          code: 'VEHICLE_AGE',
          category: RiskForecastCategory.wear,
          title: 'Usure liée à l’âge',
          detail:
              'Le véhicule a ${profile.vehicleAgeYears} ans. Certains organes vieillissent même avec un faible kilométrage.',
          action:
              'Renforcez les contrôles visuels des fluides, durites, pneus, batterie et éléments de sécurité.',
          points: agePoints,
          horizon: RiskForecastHorizon.twelveMonths,
          confidence: RiskForecastConfidence.medium,
          safetyCritical: false,
        ),
      );
    }

    var mileagePoints = 0;
    if (profile.currentMileage >= 200000) {
      mileagePoints = 12;
    } else if (profile.currentMileage >= 150000) {
      mileagePoints = 8;
    } else if (profile.currentMileage >= 100000) {
      mileagePoints = 4;
    }
    if (mileagePoints > 0) {
      factors.add(
        RiskForecastFactor(
          code: 'HIGH_MILEAGE',
          category: RiskForecastCategory.wear,
          title: 'Kilométrage à prendre en compte',
          detail:
              'Le kilométrage déclaré est de ${profile.currentMileage} km. Il ne prédit pas seul une panne.',
          action:
              'Vérifiez que les opérations importantes prévues par le constructeur sont documentées.',
          points: mileagePoints,
          horizon: RiskForecastHorizon.twelveMonths,
          confidence: RiskForecastConfidence.medium,
          safetyCritical: false,
        ),
      );
    }
  }

  static void _addUsageFactors(
    RiskForecastProfile profile,
    List<RiskForecastFactor> factors,
  ) {
    if (profile.annualMileage >= 30000) {
      factors.add(
        const RiskForecastFactor(
          code: 'HIGH_ANNUAL_MILEAGE',
          category: RiskForecastCategory.usage,
          title: 'Usage annuel intensif',
          detail:
              'Le kilométrage annuel déclaré accélère certaines échéances d’entretien et d’usure.',
          action:
              'Pilotez les échéances au kilométrage plutôt qu’uniquement à la date.',
          points: 10,
          horizon: RiskForecastHorizon.ninetyDays,
          confidence: RiskForecastConfidence.medium,
          safetyCritical: false,
        ),
      );
    } else if (profile.annualMileage >= 20000) {
      factors.add(
        const RiskForecastFactor(
          code: 'SUSTAINED_ANNUAL_MILEAGE',
          category: RiskForecastCategory.usage,
          title: 'Usage annuel soutenu',
          detail:
              'Le kilométrage annuel déclaré peut rapprocher les opérations d’entretien.',
          action: 'Mettez régulièrement à jour le kilométrage dans AutoClair.',
          points: 6,
          horizon: RiskForecastHorizon.ninetyDays,
          confidence: RiskForecastConfidence.medium,
          safetyCritical: false,
        ),
      );
    }

    if (profile.shortTripsOften) {
      factors.add(
        const RiskForecastFactor(
          code: 'SHORT_TRIPS',
          category: RiskForecastCategory.usage,
          title: 'Trajets courts fréquents',
          detail:
              'Les démarrages répétés et les trajets courts peuvent solliciter davantage batterie et mécanique.',
          action:
              'Surveillez la batterie et respectez les intervalles adaptés à un usage sévère.',
          points: 6,
          horizon: RiskForecastHorizon.ninetyDays,
          confidence: RiskForecastConfidence.medium,
          safetyCritical: false,
        ),
      );
    }

    if (profile.intensiveUse) {
      factors.add(
        const RiskForecastFactor(
          code: 'INTENSIVE_USE',
          category: RiskForecastCategory.usage,
          title: 'Usage contraignant déclaré',
          detail:
              'Charge fréquente, remorquage, montagne ou circulation dense peuvent augmenter l’usure.',
          action:
              'Demandez au professionnel si un calendrier d’entretien renforcé est adapté.',
          points: 8,
          horizon: RiskForecastHorizon.ninetyDays,
          confidence: RiskForecastConfidence.medium,
          safetyCritical: false,
        ),
      );
    }

    if (profile.longImmobilization) {
      factors.add(
        const RiskForecastFactor(
          code: 'LONG_IMMOBILIZATION',
          category: RiskForecastCategory.battery,
          title: 'Immobilisation prolongée',
          detail:
              'Une immobilisation régulière peut affecter batterie, pneumatiques et certains fluides.',
          action:
              'Contrôlez la batterie, la pression des pneus et les niveaux avant une reprise prolongée.',
          points: 8,
          horizon: RiskForecastHorizon.thirtyDays,
          confidence: RiskForecastConfidence.medium,
          safetyCritical: false,
        ),
      );
    }
  }

  static void _addReliabilityFactors(
    RiskForecastProfile profile,
    List<RiskForecastFactor> factors,
  ) {
    if (profile.startingConcern) {
      factors.add(
        const RiskForecastFactor(
          code: 'STARTING_CONCERN',
          category: RiskForecastCategory.battery,
          title: 'Démarrage moins fiable',
          detail:
              'Une difficulté de démarrage peut avoir plusieurs causes et ne permet pas de désigner une pièce.',
          action:
              'Faites tester la batterie et le circuit de démarrage avant l’immobilisation du véhicule.',
          points: 12,
          horizon: RiskForecastHorizon.thirtyDays,
          confidence: RiskForecastConfidence.strong,
          safetyCritical: false,
        ),
      );
    }

    final breakdowns = profile.repeatedBreakdowns12m;
    if (breakdowns <= 0) return;
    final points = breakdowns >= 3
        ? 20
        : breakdowns == 2
        ? 14
        : 7;
    factors.add(
      RiskForecastFactor(
        code: 'REPEATED_BREAKDOWNS',
        category: RiskForecastCategory.maintenance,
        title: 'Pannes récentes répétées',
        detail:
            '$breakdowns panne${breakdowns > 1 ? 's' : ''} ou immobilisation${breakdowns > 1 ? 's' : ''} ont été déclarées sur douze mois.',
        action:
            'Regroupez les factures et demandez une recherche de cause globale plutôt qu’un remplacement isolé.',
        points: points,
        horizon: breakdowns >= 2
            ? RiskForecastHorizon.thirtyDays
            : RiskForecastHorizon.ninetyDays,
        confidence: RiskForecastConfidence.strong,
        safetyCritical: false,
      ),
    );
  }
}
