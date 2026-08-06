import 'trip_readiness_models.dart';

class TripReadinessCalculator {
  const TripReadinessCalculator._();

  static TripReadinessAssessment assess(TripReadinessProfile profile) {
    profile.validate();

    var checked = 0;
    var points = 0;
    var possiblePoints = 0;
    final findings = <TripReadinessFinding>[];

    for (final area in TripReadinessArea.values) {
      final status = profile.checks[area] ?? TripCheckStatus.notChecked;
      if (status == TripCheckStatus.notChecked) continue;
      checked++;
      final weight = area.isSafetyCritical ? 14 : 8;
      possiblePoints += weight;
      points += switch (status) {
        TripCheckStatus.ready => weight,
        TripCheckStatus.attention => (weight * 0.55).round(),
        TripCheckStatus.blocking => 0,
        TripCheckStatus.notChecked => 0,
      };
      if (status == TripCheckStatus.attention ||
          status == TripCheckStatus.blocking) {
        findings.add(
          TripReadinessFinding(
            code: area.databaseValue,
            title: area.label,
            detail: status.label,
            action: _actionFor(area, status),
            blocking: status == TripCheckStatus.blocking,
          ),
        );
      }
    }

    _addContextFindings(profile, findings);

    final completeness = ((checked / TripReadinessArea.values.length) * 100)
        .round();
    final score = possiblePoints == 0
        ? 0
        : ((points / possiblePoints) * 100).round().clamp(0, 100).toInt();
    final hasCriticalBlocking = TripReadinessArea.values.any(
      (area) =>
          area.isSafetyCritical &&
          profile.checks[area] == TripCheckStatus.blocking,
    );
    final effectiveBlocking =
        hasCriticalBlocking || findings.any((finding) => finding.blocking);

    final level = effectiveBlocking
        ? TripReadinessLevel.blocked
        : completeness < 70
        ? TripReadinessLevel.review
        : score < 70 || findings.length >= 3
        ? TripReadinessLevel.action
        : findings.isNotEmpty || completeness < 100
        ? TripReadinessLevel.review
        : TripReadinessLevel.ready;

    findings.sort((a, b) {
      if (a.blocking != b.blocking) return a.blocking ? -1 : 1;
      return a.title.compareTo(b.title);
    });

    return TripReadinessAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      blockingCount: findings.where((finding) => finding.blocking).length,
      findings: List.unmodifiable(findings),
    );
  }

  static void _addContextFindings(
    TripReadinessProfile profile,
    List<TripReadinessFinding> findings,
  ) {
    final restStatus = profile.checks[TripReadinessArea.driverRest];
    if (profile.longDistance && restStatus != TripCheckStatus.ready) {
      _addUnique(
        findings,
        const TripReadinessFinding(
          code: 'LONG_DISTANCE_REST',
          title: 'Repos pour un long trajet',
          detail: 'Le repos du conducteur n’est pas confirmé.',
          action:
              'Reporter le départ si nécessaire et prévoir des pauses régulières.',
          blocking: true,
        ),
      );
    }

    final tireStatus = profile.checks[TripReadinessArea.tires];
    if (profile.coldConditions && tireStatus != TripCheckStatus.ready) {
      _addUnique(
        findings,
        const TripReadinessFinding(
          code: 'COLD_TIRES',
          title: 'Pneus et conditions froides',
          detail:
              'L’adaptation des pneus aux conditions froides n’est pas confirmée.',
          action:
              'Vérifier pression, état et équipements requis avant le départ.',
          blocking: false,
        ),
      );
    }

    final loadStatus = profile.checks[TripReadinessArea.load];
    if (profile.towing && loadStatus != TripCheckStatus.ready) {
      _addUnique(
        findings,
        const TripReadinessFinding(
          code: 'TOWING_LOAD',
          title: 'Remorque ou charge tractée',
          detail: 'L’arrimage et les limites de charge ne sont pas confirmés.',
          action: 'Contrôler attelage, poids, éclairage et arrimage.',
          blocking: false,
        ),
      );
    }

    final passengerStatus = profile.checks[TripReadinessArea.passengers];
    if (profile.youngPassengers && passengerStatus != TripCheckStatus.ready) {
      _addUnique(
        findings,
        const TripReadinessFinding(
          code: 'YOUNG_PASSENGERS',
          title: 'Installation des jeunes passagers',
          detail: 'Les sièges ou dispositifs adaptés ne sont pas confirmés.',
          action:
              'Vérifier installation, fixation et compatibilité avant le départ.',
          blocking: false,
        ),
      );
    }

    if (!profile.breakdownCoverageKnown) {
      _addUnique(
        findings,
        const TripReadinessFinding(
          code: 'BREAKDOWN_COVERAGE',
          title: 'Assistance en cas de panne',
          detail:
              'Le numéro et le périmètre de l’assistance ne sont pas confirmés.',
          action: 'Retrouver le contrat et enregistrer le numéro d’assistance.',
          blocking: false,
        ),
      );
    }
  }

  static void _addUnique(
    List<TripReadinessFinding> findings,
    TripReadinessFinding finding,
  ) {
    if (findings.any((current) => current.code == finding.code)) return;
    findings.add(finding);
  }

  static String _actionFor(TripReadinessArea area, TripCheckStatus status) {
    final prefix = status == TripCheckStatus.blocking
        ? 'Corriger ou faire contrôler avant le départ.'
        : 'Vérifier avant le départ.';
    return switch (area) {
      TripReadinessArea.vehicleDocuments =>
        '$prefix Contrôler permis, assurance et certificat d’immatriculation.',
      TripReadinessArea.tires =>
        '$prefix Contrôler état, pression et roue ou solution de secours.',
      TripReadinessArea.fluids =>
        '$prefix Contrôler niveaux et toute trace de fuite.',
      TripReadinessArea.lights =>
        '$prefix Tester feux, essuie-glaces et visibilité.',
      TripReadinessArea.safetyEquipment =>
        '$prefix Vérifier gilet, triangle et équipements imposés.',
      TripReadinessArea.load =>
        '$prefix Répartir et arrimer le chargement sans masquer la visibilité.',
      TripReadinessArea.driverRest =>
        '$prefix Ne pas conduire en cas de fatigue ou d’inaptitude.',
      TripReadinessArea.passengers =>
        '$prefix Vérifier ceintures et dispositifs adaptés.',
      TripReadinessArea.routeBreaks =>
        '$prefix Prévoir les pauses et une solution en cas d’imprévu.',
      TripReadinessArea.emergencyKit =>
        '$prefix Préparer eau, chargeur et éléments utiles selon le trajet.',
    };
  }
}
