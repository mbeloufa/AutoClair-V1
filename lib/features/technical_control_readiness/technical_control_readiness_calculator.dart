import 'technical_control_readiness_models.dart';

class TechnicalControlReadinessCalculator {
  const TechnicalControlReadinessCalculator._();

  static TechnicalControlReadinessAssessment assess(
    TechnicalControlReadinessProfile profile,
  ) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var blockingCount = 0;
    final findings = <TechnicalControlFinding>[];

    for (final area in TechnicalControlArea.values) {
      final status = profile.checks[area]!;
      if (status != TechnicalControlCheckStatus.notChecked) {
        checkedCount++;
      }
      if (status == TechnicalControlCheckStatus.professionalCheck) {
        score -= area.isSafetyCritical ? 7 : 4;
        findings.add(
          TechnicalControlFinding(
            code: '${area.databaseValue}_PRO',
            title: area.label,
            action: area.isSafetyCritical
                ? 'Faire contrôler ce point avant le rendez-vous.'
                : 'Demander une vérification si le doute persiste.',
            blocking: false,
          ),
        );
      } else if (status == TechnicalControlCheckStatus.attention) {
        score -= area.isSafetyCritical ? 12 : 8;
        findings.add(
          TechnicalControlFinding(
            code: '${area.databaseValue}_ATTENTION',
            title: area.label,
            action: area.isSafetyCritical
                ? 'Corriger ou faire contrôler ce point rapidement.'
                : 'Corriger le défaut visible avant la visite.',
            blocking: false,
          ),
        );
      } else if (status == TechnicalControlCheckStatus.blocking) {
        score -= area.isSafetyCritical ? 24 : 18;
        blockingCount++;
        findings.add(
          TechnicalControlFinding(
            code: '${area.databaseValue}_BLOCKING',
            title: area.label,
            action:
                'Ne pas ignorer ce problème manifeste avant de circuler ou de présenter le véhicule.',
            blocking: true,
          ),
        );
      }
    }

    if (!profile.vehicleCanMoveSafely) {
      score -= 30;
      blockingCount++;
      findings.insert(
        0,
        const TechnicalControlFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Demander l’avis d’un professionnel ou une solution de transport adaptée.',
          blocking: true,
        ),
      );
    }

    if (profile.warningLightOn) {
      score -= 12;
      findings.add(
        const TechnicalControlFinding(
          code: 'WARNING_LIGHT',
          title: 'Voyant allumé',
          action:
              'Identifier le voyant et faire contrôler sa cause avant la visite.',
          blocking: false,
        ),
      );
    }

    if (profile.visitContext == TechnicalControlVisitContext.counterVisit &&
        checkedCount < TechnicalControlArea.values.length) {
      score -= 5;
      findings.add(
        const TechnicalControlFinding(
          code: 'COUNTER_VISIT_INCOMPLETE',
          title: 'Contre-visite à préparer',
          action:
              'Reprendre le procès-verbal précédent et vérifier chaque point concerné.',
          blocking: false,
        ),
      );
    }

    score = score.clamp(0, 100).toInt();
    final completeness =
        ((checkedCount / TechnicalControlArea.values.length) * 100).round();
    final level = blockingCount > 0
        ? TechnicalControlReadinessLevel.blocked
        : score < 65
        ? TechnicalControlReadinessLevel.action
        : completeness < 100 || score < 85
        ? TechnicalControlReadinessLevel.review
        : TechnicalControlReadinessLevel.ready;

    return TechnicalControlReadinessAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      blockingCount: blockingCount,
      findings: findings,
    );
  }
}
