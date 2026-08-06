import 'fluid_care_models.dart';

class FluidCareCalculator {
  const FluidCareCalculator._();

  static FluidCareAssessment assess(FluidCareProfile profile) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <FluidCareFinding>[];

    for (final area in FluidCareArea.values) {
      final status = profile.checks[area]!;
      if (status != FluidCareStatus.notChecked) {
        checkedCount++;
      }
      if (status == FluidCareStatus.monitor) {
        score -= area.isSafetyCritical ? 8 : 4;
        findings.add(
          FluidCareFinding(
            code: '${area.databaseValue}_MONITOR',
            title: area.label,
            action:
                'Surveiller ce point et comparer uniquement avec la notice du véhicule.',
            urgent: false,
          ),
        );
      } else if (status == FluidCareStatus.action) {
        score -= area.isSafetyCritical ? 16 : 10;
        findings.add(
          FluidCareFinding(
            code: '${area.databaseValue}_ACTION',
            title: area.label,
            action:
                'Prévoir un contrôle adapté sans ajouter de produit au hasard.',
            urgent: false,
          ),
        );
      } else if (status == FluidCareStatus.urgent) {
        score -= area.isSafetyCritical ? 30 : 20;
        urgentCount++;
        findings.add(
          FluidCareFinding(
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
        const FluidCareFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Organiser une assistance ou un contrôle adapté.',
          urgent: true,
        ),
      );
    }

    if (profile.visibleLeakObserved) {
      score -= 18;
      findings.add(
        const FluidCareFinding(
          code: 'VISIBLE_LEAK_OBSERVED',
          title: 'Trace ou fuite visible déclarée',
          action:
              'Éviter toute conclusion sur le fluide concerné et demander un contrôle.',
          urgent: false,
        ),
      );
    }

    if (profile.warningMessageOn) {
      score -= 14;
      findings.add(
        const FluidCareFinding(
          code: 'WARNING_MESSAGE_ON',
          title: 'Voyant ou message déclaré',
          action:
              'Consulter la notice et demander un avis adapté au message affiché.',
          urgent: false,
        ),
      );
    }

    if (profile.checkContext == FluidCheckContext.afterLeakObservation &&
        profile.checks[FluidCareArea.visibleLeaks] ==
            FluidCareStatus.notChecked) {
      score -= 6;
      findings.add(
        const FluidCareFinding(
          code: 'LEAK_CONTEXT_INCOMPLETE',
          title: 'Contexte de fuite non vérifié',
          action:
              'Compléter le point sur les traces visibles avant d’enregistrer le contrôle.',
          urgent: false,
        ),
      );
    }

    score = score.clamp(0, 100).toInt();
    final completeness = ((checkedCount / FluidCareArea.values.length) * 100)
        .round();
    final level = urgentCount > 0
        ? FluidCareLevel.urgent
        : score < 65
        ? FluidCareLevel.action
        : completeness < 100 || score < 88 || findings.isNotEmpty
        ? FluidCareLevel.review
        : FluidCareLevel.ready;

    return FluidCareAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
