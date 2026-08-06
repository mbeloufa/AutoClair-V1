import 'tire_care_models.dart';

class TireCareCalculator {
  const TireCareCalculator._();

  static TireCareAssessment assess(TireCareProfile profile) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <TireCareFinding>[];

    for (final area in TireCareArea.values) {
      final status = profile.checks[area]!;
      if (status != TireCareStatus.notChecked) {
        checkedCount++;
      }
      if (status == TireCareStatus.monitor) {
        score -= area.isSafetyCritical ? 7 : 4;
        findings.add(
          TireCareFinding(
            code: '${area.databaseValue}_MONITOR',
            title: area.label,
            action:
                'Surveiller ce point et le faire contrôler en cas d’évolution.',
            urgent: false,
          ),
        );
      } else if (status == TireCareStatus.action) {
        score -= area.isSafetyCritical ? 15 : 10;
        findings.add(
          TireCareFinding(
            code: '${area.databaseValue}_ACTION',
            title: area.label,
            action: area.isSafetyCritical
                ? 'Faire vérifier ce point avant un trajet important.'
                : 'Prévoir une vérification ou une action adaptée.',
            urgent: false,
          ),
        );
      } else if (status == TireCareStatus.urgent) {
        score -= area.isSafetyCritical ? 28 : 20;
        urgentCount++;
        findings.add(
          TireCareFinding(
            code: '${area.databaseValue}_URGENT',
            title: area.label,
            action:
                'Demander un avis professionnel avant de poursuivre l’utilisation.',
            urgent: true,
          ),
        );
      }
    }

    if (!profile.vehicleCanMoveSafely) {
      score -= 40;
      urgentCount++;
      findings.insert(
        0,
        const TireCareFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Organiser un contrôle ou un transport adapté.',
          urgent: true,
        ),
      );
    }

    if (profile.vibrationOrPulling) {
      score -= 12;
      findings.add(
        const TireCareFinding(
          code: 'VIBRATION_OR_PULLING',
          title: 'Vibration ou tirage déclaré',
          action:
              'Faire contrôler les pneus, les roues et la géométrie sans déduire seul la cause.',
          urgent: false,
        ),
      );
    }

    if (profile.recentImpact) {
      score -= 8;
      findings.add(
        const TireCareFinding(
          code: 'RECENT_IMPACT',
          title: 'Choc récent déclaré',
          action:
              'Inspecter la roue et le pneu concernés et demander un contrôle en cas de doute.',
          urgent: false,
        ),
      );
    }

    if (profile.checkContext == TireCheckContext.seasonalChange &&
        profile.checks[TireCareArea.seasonalSuitability] !=
            TireCareStatus.good) {
      score -= 5;
      findings.add(
        const TireCareFinding(
          code: 'SEASONAL_SUITABILITY',
          title: 'Adéquation saisonnière',
          action:
              'Vérifier que le montage correspond aux conditions prévues et aux consignes applicables.',
          urgent: false,
        ),
      );
    }

    score = score.clamp(0, 100).toInt();
    final completeness = ((checkedCount / TireCareArea.values.length) * 100)
        .round();
    final level = urgentCount > 0
        ? TireCareLevel.urgent
        : score < 65
        ? TireCareLevel.action
        : completeness < 100 || score < 88 || findings.isNotEmpty
        ? TireCareLevel.review
        : TireCareLevel.ready;

    return TireCareAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
