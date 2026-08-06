import 'workshop_visit_preparation_models.dart';

class WorkshopVisitPreparationCalculator {
  const WorkshopVisitPreparationCalculator._();

  static WorkshopVisitPreparationAssessment assess(
    WorkshopVisitPreparationProfile profile,
  ) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <WorkshopPreparationFinding>[];

    for (final area in WorkshopPreparationArea.values) {
      final status = profile.checks[area]!;
      if (status != WorkshopPreparationStatus.notChecked) {
        checkedCount++;
      }
      if (status == WorkshopPreparationStatus.discussWithProfessional) {
        score -= area.isSafetyCritical ? 7 : 4;
        findings.add(
          WorkshopPreparationFinding(
            code: '${area.databaseValue}_DISCUSS',
            title: area.label,
            action: 'Ajouter ce point aux questions à poser au garage.',
            urgent: false,
          ),
        );
      } else if (status == WorkshopPreparationStatus.toPrepare) {
        score -= area.isSafetyCritical ? 12 : 8;
        findings.add(
          WorkshopPreparationFinding(
            code: '${area.databaseValue}_PREPARE',
            title: area.label,
            action: area.isSafetyCritical
                ? 'Clarifier ce point avant de déplacer le véhicule.'
                : 'Préparer cette information avant le rendez-vous.',
            urgent: false,
          ),
        );
      } else if (status == WorkshopPreparationStatus.urgent) {
        score -= area.isSafetyCritical ? 25 : 18;
        urgentCount++;
        findings.add(
          WorkshopPreparationFinding(
            code: '${area.databaseValue}_URGENT',
            title: area.label,
            action:
                'Demander rapidement un avis professionnel avant de circuler.',
            urgent: true,
          ),
        );
      }
    }

    if (!profile.vehicleCanMoveSafely) {
      score -= 35;
      urgentCount++;
      findings.insert(
        0,
        const WorkshopPreparationFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Organiser un avis ou un transport adapté.',
          urgent: true,
        ),
      );
    }

    if (profile.warningLightOn) {
      score -= 12;
      findings.add(
        const WorkshopPreparationFinding(
          code: 'WARNING_LIGHT',
          title: 'Voyant allumé',
          action:
              'Noter le voyant observé sans tenter d’en déduire seul la cause.',
          urgent: false,
        ),
      );
    }

    final symptomReason =
        profile.visitReason == WorkshopVisitReason.warningLight ||
        profile.visitReason == WorkshopVisitReason.noiseOrVibration ||
        profile.visitReason == WorkshopVisitReason.leakOrOdor ||
        profile.visitReason == WorkshopVisitReason.brakingOrSteering;
    if (symptomReason &&
        profile.checks[WorkshopPreparationArea.symptomConditions] !=
            WorkshopPreparationStatus.ready) {
      score -= 5;
      findings.add(
        const WorkshopPreparationFinding(
          code: 'SYMPTOM_CONTEXT',
          title: 'Circonstances du symptôme',
          action:
              'Préparer quand, à quelle fréquence et dans quelles conditions le phénomène apparaît.',
          urgent: false,
        ),
      );
    }

    score = score.clamp(0, 100).toInt();
    final completeness =
        ((checkedCount / WorkshopPreparationArea.values.length) * 100).round();
    final level = urgentCount > 0
        ? WorkshopPreparationLevel.urgent
        : score < 65
        ? WorkshopPreparationLevel.action
        : completeness < 100 || score < 85 || findings.isNotEmpty
        ? WorkshopPreparationLevel.review
        : WorkshopPreparationLevel.ready;

    return WorkshopVisitPreparationAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
