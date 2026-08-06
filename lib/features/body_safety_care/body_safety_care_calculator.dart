import 'body_safety_care_models.dart';

class BodySafetyCareCalculator {
  const BodySafetyCareCalculator._();

  static BodySafetyCareAssessment assess(BodySafetyCareProfile profile) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <BodySafetyCareFinding>[];

    for (final area in BodySafetyCareArea.values) {
      final status = profile.checks[area]!;
      if (status != BodySafetyCareStatus.notChecked) {
        checkedCount++;
      }
      if (status == BodySafetyCareStatus.monitor) {
        score -= area.isSafetyCritical ? 8 : 4;
        findings.add(
          BodySafetyCareFinding(
            code: '${area.databaseValue}_MONITOR',
            title: area.label,
            action:
                'Surveiller ce point et le vérifier de nouveau avant un trajet exigeant.',
            urgent: false,
          ),
        );
      } else if (status == BodySafetyCareStatus.action) {
        score -= area.isSafetyCritical ? 17 : 10;
        findings.add(
          BodySafetyCareFinding(
            code: '${area.databaseValue}_ACTION',
            title: area.label,
            action:
                'Prévoir un contrôle professionnel sans démonter ni redresser un élément au hasard.',
            urgent: false,
          ),
        );
      } else if (status == BodySafetyCareStatus.urgent) {
        score -= area.isSafetyCritical ? 32 : 20;
        urgentCount++;
        findings.add(
          BodySafetyCareFinding(
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
        const BodySafetyCareFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Organiser une assistance ou un contrôle adapté.',
          urgent: true,
        ),
      );
    }

    if (profile.closureConcern) {
      score -= 22;
      findings.add(
        const BodySafetyCareFinding(
          code: 'CLOSURE_CONCERN',
          title: 'Fermeture ou verrouillage incertain',
          action:
              'Faire contrôler l’ouvrant concerné avant un trajet ou un usage normal.',
          urgent: false,
        ),
      );
    }

    if (profile.restraintConcern) {
      score -= 22;
      findings.add(
        const BodySafetyCareFinding(
          code: 'RESTRAINT_CONCERN',
          title: 'Ceinture, siège ou appuie-tête à contrôler',
          action: 'Ne pas utiliser la place concernée avant un avis adapté.',
          urgent: false,
        ),
      );
    }

    if (profile.recentImpact) {
      final impactAreas = <BodySafetyCareArea>[
        BodySafetyCareArea.doorsAndLocks,
        BodySafetyCareArea.hoodClosure,
        BodySafetyCareArea.trunkAndTailgate,
        BodySafetyCareArea.bodyFixingsAndSharpEdges,
      ];
      final incomplete = impactAreas.any(
        (area) => profile.checks[area] == BodySafetyCareStatus.notChecked,
      );
      if (incomplete) {
        score -= 8;
        findings.add(
          const BodySafetyCareFinding(
            code: 'RECENT_IMPACT_CHECK_INCOMPLETE',
            title: 'Contrôle après choc incomplet',
            action:
                'Vérifier les ouvrants, fixations et éléments saillants avant de reprendre un usage normal.',
            urgent: false,
          ),
        );
      }
    }

    if (profile.checkContext == BodySafetyCheckContext.beforeControlOrSale) {
      final incomplete = <BodySafetyCareArea>[
        BodySafetyCareArea.platesAndReflectors,
        BodySafetyCareArea.seatBelts,
        BodySafetyCareArea.bodyFixingsAndSharpEdges,
      ].any((area) => profile.checks[area] == BodySafetyCareStatus.notChecked);
      if (incomplete) {
        score -= 8;
        findings.add(
          const BodySafetyCareFinding(
            code: 'CONTROL_OR_SALE_CONTEXT_INCOMPLETE',
            title: 'Préparation avant contrôle ou vente incomplète',
            action:
                'Compléter les points plaques, ceintures et fixations visibles avant de partager le résumé.',
            urgent: false,
          ),
        );
      }
    }

    score = score.clamp(0, 100).toInt();
    final completeness =
        ((checkedCount / BodySafetyCareArea.values.length) * 100).round();
    final level = urgentCount > 0
        ? BodySafetyCareLevel.urgent
        : score < 65
        ? BodySafetyCareLevel.action
        : completeness < 100 || score < 88 || findings.isNotEmpty
        ? BodySafetyCareLevel.review
        : BodySafetyCareLevel.ready;

    return BodySafetyCareAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
