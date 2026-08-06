import 'battery_care_models.dart';

class BatteryCareCalculator {
  const BatteryCareCalculator._();

  static BatteryCareAssessment assess(BatteryCareProfile profile) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <BatteryCareFinding>[];

    for (final area in BatteryCareArea.values) {
      final status = profile.checks[area]!;
      if (status != BatteryCareStatus.notChecked) {
        checkedCount++;
      }
      if (status == BatteryCareStatus.monitor) {
        score -= area.isSafetyCritical ? 8 : 4;
        findings.add(
          BatteryCareFinding(
            code: '${area.databaseValue}_MONITOR',
            title: area.label,
            action:
                'Surveiller ce point et noter toute évolution avant le prochain trajet.',
            urgent: false,
          ),
        );
      } else if (status == BatteryCareStatus.action) {
        score -= area.isSafetyCritical ? 16 : 10;
        findings.add(
          BatteryCareFinding(
            code: '${area.databaseValue}_ACTION',
            title: area.label,
            action: 'Prévoir un contrôle adapté sans déduire seul la cause.',
            urgent: false,
          ),
        );
      } else if (status == BatteryCareStatus.urgent) {
        score -= area.isSafetyCritical ? 30 : 20;
        urgentCount++;
        findings.add(
          BatteryCareFinding(
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
        const BatteryCareFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas circuler dans cet état. Organiser une assistance ou un contrôle adapté.',
          urgent: true,
        ),
      );
    }

    if (profile.difficultStart) {
      score -= 14;
      findings.add(
        const BatteryCareFinding(
          code: 'DIFFICULT_START',
          title: 'Démarrage difficile déclaré',
          action:
              'Faire contrôler la batterie et le circuit de charge sans conclure sur la cause.',
          urgent: false,
        ),
      );
    }

    if (profile.recentDischarge) {
      score -= 12;
      findings.add(
        const BatteryCareFinding(
          code: 'RECENT_DISCHARGE',
          title: 'Décharge récente déclarée',
          action:
              'Prévoir un contrôle et rechercher la cause avec un professionnel.',
          urgent: false,
        ),
      );
    }

    if (profile.parkedMoreThan14Days &&
        profile.checks[BatteryCareArea.longParkingPreparation] !=
            BatteryCareStatus.normal) {
      score -= 6;
      findings.add(
        const BatteryCareFinding(
          code: 'LONG_PARKING_PREPARATION',
          title: 'Reprise après immobilisation',
          action:
              'Vérifier la préparation de la batterie selon la notice du véhicule.',
          urgent: false,
        ),
      );
    }

    score = score.clamp(0, 100).toInt();
    final completeness = ((checkedCount / BatteryCareArea.values.length) * 100)
        .round();
    final level = urgentCount > 0
        ? BatteryCareLevel.urgent
        : score < 65
        ? BatteryCareLevel.action
        : completeness < 100 || score < 88 || findings.isNotEmpty
        ? BatteryCareLevel.review
        : BatteryCareLevel.ready;

    return BatteryCareAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
