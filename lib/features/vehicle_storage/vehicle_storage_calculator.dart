import 'vehicle_storage_models.dart';

class VehicleStorageCalculator {
  const VehicleStorageCalculator._();

  static VehicleStorageAssessment assess(VehicleStorageProfile profile) {
    profile.validate();
    final relevantAreas = VehicleStorageArea.values
        .where(
          (area) =>
              area != VehicleStorageArea.tractionBattery ||
              profile.electricOrHybrid,
        )
        .toList(growable: false);
    var score = 100;
    var checkedCount = 0;
    var blockingCount = 0;
    var attentionCount = 0;
    final findings = <VehicleStorageFinding>[];

    for (final area in relevantAreas) {
      final status = profile.checks[area]!;
      if (status != VehicleStorageStatus.notChecked &&
          status != VehicleStorageStatus.notApplicable) {
        checkedCount++;
      }
      if (status == VehicleStorageStatus.attention) {
        attentionCount++;
        score -= area.isSafetyCritical ? 12 : 8;
        findings.add(
          VehicleStorageFinding(
            code: '${area.databaseValue}_ATTENTION',
            title: area.label,
            detail: 'Ce point a été déclaré à vérifier.',
            action: _actionFor(area),
            blocking: false,
          ),
        );
      }
      if (status == VehicleStorageStatus.blocking) {
        blockingCount++;
        score -= area.isSafetyCritical ? 28 : 20;
        findings.add(
          VehicleStorageFinding(
            code: '${area.databaseValue}_BLOCKING',
            title: area.label,
            detail: 'Ce point a été déclaré prioritaire.',
            action: _actionFor(area),
            blocking: true,
          ),
        );
      }
    }

    final battery12 = profile.checks[VehicleStorageArea.twelveVoltBattery]!;
    if (profile.plannedWeeks >= 8 && battery12 != VehicleStorageStatus.ready) {
      _addUnique(
        findings,
        const VehicleStorageFinding(
          code: 'LONG_STORAGE_12V',
          title: 'Batterie 12 V à anticiper',
          detail:
              'Une immobilisation longue augmente le risque de batterie déchargée.',
          action:
              'Suivez la procédure du constructeur ou demandez conseil à un professionnel.',
          blocking: false,
        ),
      );
    }

    final traction = profile.checks[VehicleStorageArea.tractionBattery]!;
    if (profile.electricOrHybrid && traction != VehicleStorageStatus.ready) {
      _addUnique(
        findings,
        const VehicleStorageFinding(
          code: 'TRACTION_BATTERY',
          title: 'Batterie de traction à préparer',
          detail:
              'Le niveau de charge et les consignes d’immobilisation varient selon le modèle.',
          action: 'Consultez le manuel constructeur avant la période d’arrêt.',
          blocking: false,
        ),
      );
    }

    final protection =
        profile.checks[VehicleStorageArea.ventilationAndProtection]!;
    if ((profile.outdoorStorage || profile.humidEnvironment) &&
        protection != VehicleStorageStatus.ready) {
      _addUnique(
        findings,
        const VehicleStorageFinding(
          code: 'ENVIRONMENT_PROTECTION',
          title: 'Protection de l’environnement à vérifier',
          detail:
              'L’exposition extérieure ou à l’humidité demande une préparation adaptée.',
          action:
              'Prévoyez une protection ventilée et compatible avec le véhicule.',
          blocking: false,
        ),
      );
    }

    final tires = profile.checks[VehicleStorageArea.tires]!;
    if (profile.plannedWeeks >= 12 && tires != VehicleStorageStatus.ready) {
      _addUnique(
        findings,
        const VehicleStorageFinding(
          code: 'LONG_STORAGE_TIRES',
          title: 'Pneus à contrôler avant une longue pause',
          detail:
              'Une immobilisation prolongée peut marquer les appuis et modifier la pression.',
          action:
              'Contrôlez les recommandations du constructeur et l’état des pneus.',
          blocking: false,
        ),
      );
    }

    final restartPlan = profile.checks[VehicleStorageArea.restartPlan]!;
    if (profile.scenario == VehicleStorageScenario.restart &&
        restartPlan != VehicleStorageStatus.ready) {
      _addUnique(
        findings,
        const VehicleStorageFinding(
          code: 'RESTART_PLAN',
          title: 'Remise en route à organiser',
          detail:
              'La reprise doit commencer par des contrôles visuels et fonctionnels.',
          action:
              'Inspectez le véhicule et faites contrôler tout signal anormal avant de rouler.',
          blocking: false,
        ),
      );
    }

    final administrative =
        profile.checks[VehicleStorageArea.insuranceAndDocuments]!;
    if (administrative != VehicleStorageStatus.ready) {
      _addUnique(
        findings,
        const VehicleStorageFinding(
          code: 'INSURANCE_DOCUMENTS',
          title: 'Assurance et documents à confirmer',
          detail:
              'Une immobilisation ne supprime pas automatiquement les obligations contractuelles.',
          action:
              'Vérifiez les garanties et conditions auprès de votre assureur.',
          blocking: false,
        ),
      );
    }

    score = score.clamp(0, 100).toInt();
    final completeness = relevantAreas.isEmpty
        ? 0
        : ((checkedCount * 100) / relevantAreas.length).round();
    final restartCriticalBlocking =
        profile.scenario == VehicleStorageScenario.restart &&
        [
          VehicleStorageArea.tires,
          VehicleStorageArea.fluidsAndLeaks,
          VehicleStorageArea.parkingAndBrakes,
        ].any((area) => profile.checks[area] == VehicleStorageStatus.blocking);

    final level = switch ((
      blockingCount,
      restartCriticalBlocking,
      score,
      completeness,
      attentionCount,
    )) {
      (_, true, _, _, _) => VehicleStorageLevel.blocked,
      (> 0, _, _, _, _) => VehicleStorageLevel.blocked,
      (_, _, < 65, _, _) => VehicleStorageLevel.action,
      (_, _, _, _, >= 3) => VehicleStorageLevel.action,
      (_, _, _, < 80, _) => VehicleStorageLevel.review,
      (_, _, _, _, _) when findings.isNotEmpty => VehicleStorageLevel.review,
      _ => VehicleStorageLevel.ready,
    };

    return VehicleStorageAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      blockingCount: blockingCount,
      findings: findings,
    );
  }

  static void _addUnique(
    List<VehicleStorageFinding> findings,
    VehicleStorageFinding finding,
  ) {
    if (findings.any((item) => item.code == finding.code)) return;
    findings.add(finding);
  }

  static String _actionFor(VehicleStorageArea area) => switch (area) {
    VehicleStorageArea.cleanAndDry =>
      'Nettoyez et séchez le véhicule avant la période d’arrêt.',
    VehicleStorageArea.tires =>
      'Contrôlez l’état et appliquez les recommandations du constructeur.',
    VehicleStorageArea.twelveVoltBattery =>
      'Préparez la batterie 12 V selon le manuel constructeur.',
    VehicleStorageArea.tractionBattery =>
      'Respectez le niveau de charge recommandé pour ce modèle.',
    VehicleStorageArea.fuelOrCharge =>
      'Adaptez le carburant ou la charge à la durée prévue.',
    VehicleStorageArea.fluidsAndLeaks =>
      'Faites contrôler toute fuite ou niveau anormal avant l’arrêt ou la reprise.',
    VehicleStorageArea.parkingAndBrakes =>
      'Choisissez un stationnement stable et suivez les consignes du constructeur.',
    VehicleStorageArea.ventilationAndProtection =>
      'Utilisez une protection compatible, sèche et correctement ventilée.',
    VehicleStorageArea.insuranceAndDocuments =>
      'Confirmez les obligations et garanties avec l’assureur.',
    VehicleStorageArea.keysAndSecurity =>
      'Rangez les clés et moyens d’accès dans un lieu distinct et sécurisé.',
    VehicleStorageArea.restartPlan =>
      'Prévoyez une inspection avant la première remise en circulation.',
  };
}
