import 'lease_return_models.dart';

class LeaseReturnCalculator {
  const LeaseReturnCalculator._();

  static LeaseReturnAssessment assess(LeaseReturnProfile profile) {
    profile.validate();
    var score = 100;
    var checkedCount = 0;
    var urgentCount = 0;
    final findings = <LeaseReturnFinding>[];

    for (final area in LeaseReturnArea.values) {
      final status = profile.checks[area]!;
      if (status != LeaseReturnStatus.notChecked) {
        checkedCount++;
      }
      if (status == LeaseReturnStatus.toComplete) {
        score -= area.isPriorityArea ? 9 : 5;
        findings.add(
          LeaseReturnFinding(
            code: '${area.databaseValue}_TO_COMPLETE',
            title: area.label,
            action:
                'Compléter ce point à partir du contrat, des consignes du loueur ou des éléments disponibles.',
            urgent: false,
          ),
        );
      } else if (status == LeaseReturnStatus.professionalReview) {
        score -= area.isPriorityArea ? 18 : 12;
        findings.add(
          LeaseReturnFinding(
            code: '${area.databaseValue}_REVIEW',
            title: area.label,
            action:
                'Prévoir un contrôle ou demander une information écrite avant la restitution.',
            urgent: false,
          ),
        );
      } else if (status == LeaseReturnStatus.priority) {
        score -= area.isPriorityArea ? 30 : 22;
        urgentCount++;
        findings.add(
          LeaseReturnFinding(
            code: '${area.databaseValue}_PRIORITY',
            title: area.label,
            action: 'Traiter ce point en priorité avant la remise du véhicule.',
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
        const LeaseReturnFinding(
          code: 'UNSAFE_TO_MOVE',
          title: 'Déplacement du véhicule',
          action:
              'Ne pas organiser un déplacement normal. Demander une assistance ou un avis professionnel adapté.',
          urgent: true,
        ),
      );
    }

    if (!profile.contractInstructionsAvailable) {
      score -= 14;
      findings.add(
        const LeaseReturnFinding(
          code: 'CONTRACT_INSTRUCTIONS_MISSING',
          title: 'Consignes contractuelles indisponibles',
          action:
              'Retrouver le contrat et demander les modalités écrites de restitution au loueur.',
          urgent: false,
        ),
      );
    }

    if (!profile.allKeysAndAccessoriesAvailable) {
      score -= 20;
      findings.add(
        const LeaseReturnFinding(
          code: 'KEYS_OR_ACCESSORIES_MISSING',
          title: 'Clé, câble ou accessoire manquant déclaré',
          action:
              'Faire l’inventaire prévu au contrat avant le rendez-vous de restitution.',
          urgent: false,
        ),
      );
    }

    if (profile.warningOrMechanicalConcern) {
      score -= 22;
      findings.add(
        const LeaseReturnFinding(
          code: 'WARNING_OR_MECHANICAL_CONCERN',
          title: 'Voyant ou anomalie mécanique déclarée',
          action:
              'Préparer les éléments factuels et demander un avis professionnel avant la restitution.',
          urgent: false,
        ),
      );
    }

    if (profile.preparationContext == LeaseReturnContext.beforePreInspection) {
      final incomplete = <LeaseReturnArea>[
        LeaseReturnArea.exteriorGlassAndWheels,
        LeaseReturnArea.interiorAndEquipment,
        LeaseReturnArea.maintenanceAndDocuments,
        LeaseReturnArea.cleaningAndPersonalData,
        LeaseReturnArea.preInspectionAndHandover,
      ].any((area) => profile.checks[area] == LeaseReturnStatus.notChecked);
      if (incomplete) {
        score -= 8;
        findings.add(
          const LeaseReturnFinding(
            code: 'PRE_INSPECTION_INCOMPLETE',
            title: 'Préparation de la pré-inspection incomplète',
            action:
                'Compléter l’état visible, les documents, le nettoyage et les éléments de remise.',
            urgent: false,
          ),
        );
      }
    }

    if (profile.preparationContext ==
        LeaseReturnContext.compareReturnOrPurchase) {
      final incomplete = <LeaseReturnArea>[
        LeaseReturnArea.contractAndInstructions,
        LeaseReturnArea.mileageAndUsage,
        LeaseReturnArea.maintenanceAndDocuments,
      ].any((area) => profile.checks[area] == LeaseReturnStatus.notChecked);
      if (incomplete) {
        score -= 8;
        findings.add(
          const LeaseReturnFinding(
            code: 'RETURN_OR_PURCHASE_COMPARISON_INCOMPLETE',
            title: 'Comparaison restitution ou achat incomplète',
            action:
                'Rassembler les clauses, le kilométrage et l’historique avant toute comparaison financière.',
            urgent: false,
          ),
        );
      }
    }

    score = score.clamp(0, 100).toInt();
    final completeness = ((checkedCount / LeaseReturnArea.values.length) * 100)
        .round();
    final level = urgentCount > 0
        ? LeaseReturnLevel.urgent
        : score < 65
        ? LeaseReturnLevel.action
        : completeness < 100 || score < 88 || findings.isNotEmpty
        ? LeaseReturnLevel.review
        : LeaseReturnLevel.ready;

    return LeaseReturnAssessment(
      level: level,
      score: score,
      completenessPercent: completeness,
      urgentCount: urgentCount,
      findings: findings,
    );
  }
}
