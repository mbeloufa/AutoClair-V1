import 'brake_care_models.dart';

class BrakeCareCalculator {
  const BrakeCareCalculator._();

  static BrakeCareAssessment assess(BrakeCareProfile profile) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <BrakeCareFinding>[];

    for (final area in BrakeCareArea.values) {
      final status = profile.checks[area]!;
      if (status != BrakeCareStatus.notChecked) {
        checkedCount++;
      }
      if (status == BrakeCareStatus.monitor) {
        score -= area.isSafetyCritical ? 8 : 4;
        findings.add(
          BrakeCareFinding(
            code: '${area.databaseValue}_MONITOR',
            title: area.label,
            action:
                'Surveiller ce point et le contrôler de nouveau avant un trajet exigeant.',
            urgent: false,
          ),
        );
      } else if (status == BrakeCareStatus.action) {
        score -= area.isSafetyCritical ? 17 : 10;
        findings.add(
          BrakeCareFinding(
            code: '${area.databaseValue}_ACTION',
            title: area.label,
            action:
                'Prévoir un contrôle professionnel sans démonter ni remplacer une pièce au hasard.',
            urgent: false,
          ),
        );
      } else if (status == BrakeCareStatus.urgent) {
        score -= area.isSafetyCritical ? 32 : 20;
        urgentCount++;
        findings.add(
          BrakeCareFinding(
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
      score -= 45;
      urgentCount++;
      findings.insert(
        0,
        const BrakeCareFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Organiser une assistance ou un contrôle adapté.',
          urgent: true,
        ),
      );
    }

    if (profile.brakingAnomaly) {
      score -= 22;
      findings.add(
        const BrakeCareFinding(
          code: 'BRAKING_ANOMALY',
          title: 'Freinage inhabituel déclaré',
          action:
              'Éviter de banaliser cette sensation et faire contrôler le véhicule rapidement.',
          urgent: false,
        ),
      );
    }

    if (profile.steeringInstability) {
      score -= 20;
      findings.add(
        const BrakeCareFinding(
          code: 'STEERING_INSTABILITY',
          title: 'Instabilité ou déviation déclarée',
          action:
              'Faire contrôler la direction, les roues et les organes associés avant un trajet exigeant.',
          urgent: false,
        ),
      );
    }

    if (profile.recentImpact) {
      final impactAreas = <BrakeCareArea>[
        BrakeCareArea.directionalStability,
        BrakeCareArea.steeringFeel,
        BrakeCareArea.wheelAndSuspensionSigns,
      ];
      final incomplete = impactAreas.any(
        (area) => profile.checks[area] == BrakeCareStatus.notChecked,
      );
      if (incomplete) {
        score -= 8;
        findings.add(
          const BrakeCareFinding(
            code: 'RECENT_IMPACT_CHECK_INCOMPLETE',
            title: 'Contrôle après choc incomplet',
            action:
                'Vérifier la stabilité, la direction et les signes visibles avant de reprendre un usage normal.',
            urgent: false,
          ),
        );
      }
    }

    if (profile.checkContext == BrakeCheckContext.unusualBraking) {
      final incomplete = <BrakeCareArea>[
        BrakeCareArea.pedalFeel,
        BrakeCareArea.brakingResponse,
        BrakeCareArea.warningLights,
      ].any((area) => profile.checks[area] == BrakeCareStatus.notChecked);
      if (incomplete) {
        score -= 8;
        findings.add(
          const BrakeCareFinding(
            code: 'BRAKING_CONTEXT_INCOMPLETE',
            title: 'Sensation de freinage insuffisamment vérifiée',
            action:
                'Compléter les points pédale, réponse du freinage et voyants avant de partager le résumé.',
            urgent: false,
          ),
        );
      }
    }

    score = score.clamp(0, 100).toInt();
    final completeness = ((checkedCount / BrakeCareArea.values.length) * 100)
        .round();
    final level = urgentCount > 0
        ? BrakeCareLevel.urgent
        : score < 65
        ? BrakeCareLevel.action
        : completeness < 100 || score < 88 || findings.isNotEmpty
        ? BrakeCareLevel.review
        : BrakeCareLevel.ready;

    return BrakeCareAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
