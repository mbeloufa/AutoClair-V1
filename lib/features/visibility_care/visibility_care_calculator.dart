import 'visibility_care_models.dart';

class VisibilityCareCalculator {
  const VisibilityCareCalculator._();

  static VisibilityCareAssessment assess(VisibilityCareProfile profile) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <VisibilityCareFinding>[];

    for (final area in VisibilityCareArea.values) {
      final status = profile.checks[area]!;
      if (status != VisibilityCareStatus.notChecked) {
        checkedCount++;
      }
      if (status == VisibilityCareStatus.monitor) {
        score -= area.isSafetyCritical ? 8 : 4;
        findings.add(
          VisibilityCareFinding(
            code: '${area.databaseValue}_MONITOR',
            title: area.label,
            action:
                'Surveiller ce point et le contrôler de nouveau avant un trajet exigeant.',
            urgent: false,
          ),
        );
      } else if (status == VisibilityCareStatus.action) {
        score -= area.isSafetyCritical ? 16 : 10;
        findings.add(
          VisibilityCareFinding(
            code: '${area.databaseValue}_ACTION',
            title: area.label,
            action:
                'Prévoir un contrôle adapté sans démonter ni remplacer une pièce au hasard.',
            urgent: false,
          ),
        );
      } else if (status == VisibilityCareStatus.urgent) {
        score -= area.isSafetyCritical ? 30 : 20;
        urgentCount++;
        findings.add(
          VisibilityCareFinding(
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
        const VisibilityCareFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Organiser une assistance ou un contrôle adapté.',
          urgent: true,
        ),
      );
    }

    if (profile.majorVisibilityObstruction) {
      score -= 22;
      findings.add(
        const VisibilityCareFinding(
          code: 'MAJOR_VISIBILITY_OBSTRUCTION',
          title: 'Champ de vision fortement gêné',
          action:
              'Ne pas banaliser cette gêne. Demander un contrôle avant de circuler dans des conditions difficiles.',
          urgent: false,
        ),
      );
    }

    if (profile.essentialLightFailure) {
      score -= 18;
      findings.add(
        const VisibilityCareFinding(
          code: 'ESSENTIAL_LIGHT_FAILURE',
          title: 'Éclairage essentiel déclaré défaillant',
          action:
              'Éviter les conditions qui nécessitent cet éclairage et faire contrôler le véhicule.',
          urgent: false,
        ),
      );
    }

    if (profile.badWeatherExpected) {
      final weatherAreas = <VisibilityCareArea>[
        VisibilityCareArea.wipers,
        VisibilityCareArea.washerSystem,
        VisibilityCareArea.demistingAndDefrosting,
      ];
      final incomplete = weatherAreas.any(
        (area) => profile.checks[area] == VisibilityCareStatus.notChecked,
      );
      if (incomplete) {
        score -= 8;
        findings.add(
          const VisibilityCareFinding(
            code: 'BAD_WEATHER_CHECK_INCOMPLETE',
            title: 'Préparation aux intempéries incomplète',
            action:
                'Vérifier l’essuyage, le lave-glace et le désembuage avant le départ.',
            urgent: false,
          ),
        );
      }
    }

    if (profile.checkContext == VisibilityCheckContext.nightDriving &&
        profile.checks[VisibilityCareArea.lowAndHighBeams] ==
            VisibilityCareStatus.notChecked) {
      score -= 8;
      findings.add(
        const VisibilityCareFinding(
          code: 'NIGHT_LIGHTING_INCOMPLETE',
          title: 'Éclairage avant non vérifié',
          action:
              'Compléter ce contrôle avant de prévoir une conduite de nuit.',
          urgent: false,
        ),
      );
    }

    score = score.clamp(0, 100).toInt();
    final completeness =
        ((checkedCount / VisibilityCareArea.values.length) * 100).round();
    final level = urgentCount > 0
        ? VisibilityCareLevel.urgent
        : score < 65
        ? VisibilityCareLevel.action
        : completeness < 100 || score < 88 || findings.isNotEmpty
        ? VisibilityCareLevel.review
        : VisibilityCareLevel.ready;

    return VisibilityCareAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
