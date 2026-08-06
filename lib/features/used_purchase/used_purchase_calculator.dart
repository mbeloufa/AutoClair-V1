import 'used_purchase_models.dart';

class UsedPurchaseCalculator {
  static UsedPurchaseAssessment assess({
    required UsedPurchaseProfile profile,
    DateTime? now,
  }) {
    profile.validate();
    final reference = _dateOnly(now ?? DateTime.now());
    final items = <PurchaseChecklistItem>[];

    final year = profile.vehicleYear;
    final technicalControlRequired = year != null && reference.year - year >= 4;

    _addBinary(
      items,
      code: 'RIGHT_TO_SELL',
      title: 'Droit de vendre le véhicule',
      ready: profile.sellerRightToSellVerified,
      readyDetail:
          'Le vendeur peut justifier qu’il est autorisé à céder le véhicule.',
      blockingDetail:
          'Ne versez rien tant que le vendeur ne justifie pas son droit de vendre.',
    );
    _addBinary(
      items,
      code: 'REGISTRATION',
      title: 'Certificat d’immatriculation',
      ready: profile.registrationAvailable,
      readyDetail: 'La carte grise originale est disponible et lisible.',
      blockingDetail:
          'La carte grise originale doit être vérifiée avant tout engagement.',
    );
    _addBinary(
      items,
      code: 'VIN',
      title: 'Numéro VIN',
      ready: profile.vinMatchesRegistration,
      readyDetail: 'Le VIN du véhicule correspond aux documents.',
      blockingDetail:
          'Le VIN doit correspondre à la carte grise et au véhicule.',
    );

    DateTime? csaExpiresAt;
    final csaDate = profile.csaIssuedAt;
    if (csaDate == null) {
      items.add(
        const PurchaseChecklistItem(
          code: 'CSA',
          title: 'Certificat de situation administrative',
          detail: 'Demandez un certificat officiel daté de moins de 15 jours.',
          level: PurchaseCheckLevel.blocking,
        ),
      );
    } else {
      csaExpiresAt = _addCalendarDays(csaDate, 14);
      if (_dateOnly(csaDate).isAfter(reference)) {
        items.add(
          const PurchaseChecklistItem(
            code: 'CSA',
            title: 'Certificat de situation administrative',
            detail: 'La date du certificat est dans le futur.',
            level: PurchaseCheckLevel.blocking,
          ),
        );
      } else if (csaExpiresAt.isBefore(reference)) {
        items.add(
          PurchaseChecklistItem(
            code: 'CSA',
            title: 'Certificat de situation administrative',
            detail: 'Le certificat a expiré le ${_formatDate(csaExpiresAt)}.',
            level: PurchaseCheckLevel.blocking,
          ),
        );
      } else if (!profile.csaClear) {
        items.add(
          const PurchaseChecklistItem(
            code: 'CSA',
            title: 'Certificat de situation administrative',
            detail:
                'Un gage ou une opposition doit être clarifié avant l’achat.',
            level: PurchaseCheckLevel.blocking,
          ),
        );
      } else {
        items.add(
          PurchaseChecklistItem(
            code: 'CSA',
            title: 'Certificat de situation administrative',
            detail:
                'Le certificat est exploitable jusqu’au '
                '${_formatDate(csaExpiresAt)}.',
            level: PurchaseCheckLevel.ready,
          ),
        );
      }
    }

    DateTime? technicalControlExpiresAt;
    if (year == null) {
      items.add(
        const PurchaseChecklistItem(
          code: 'TECHNICAL_CONTROL_AGE',
          title: 'Âge et contrôle technique',
          detail:
              'Renseignez l’année pour déterminer si un contrôle technique est requis.',
          level: PurchaseCheckLevel.warning,
        ),
      );
    } else if (!technicalControlRequired) {
      items.add(
        const PurchaseChecklistItem(
          code: 'TECHNICAL_CONTROL',
          title: 'Contrôle technique',
          detail: 'Le véhicule a moins de 4 ans dans cette estimation.',
          level: PurchaseCheckLevel.ready,
        ),
      );
    } else {
      final controlDate = profile.technicalControlDate;
      if (controlDate == null ||
          profile.technicalControlStatus ==
              PurchaseTechnicalControlStatus.unknown ||
          profile.technicalControlStatus ==
              PurchaseTechnicalControlStatus.notRequired) {
        items.add(
          const PurchaseChecklistItem(
            code: 'TECHNICAL_CONTROL',
            title: 'Contrôle technique',
            detail: 'Un procès-verbal récent doit être remis avant la vente.',
            level: PurchaseCheckLevel.blocking,
          ),
        );
      } else {
        final validityMonths =
            profile.technicalControlStatus ==
                PurchaseTechnicalControlStatus.majorDefects
            ? 2
            : 6;
        technicalControlExpiresAt = _addCalendarMonths(
          controlDate,
          validityMonths,
        );
        if (_dateOnly(controlDate).isAfter(reference) ||
            technicalControlExpiresAt.isBefore(reference)) {
          items.add(
            PurchaseChecklistItem(
              code: 'TECHNICAL_CONTROL',
              title: 'Contrôle technique',
              detail:
                  'Le contrôle technique n’est plus valable pour la démarche.',
              level: PurchaseCheckLevel.blocking,
            ),
          );
        } else if (profile.technicalControlStatus ==
            PurchaseTechnicalControlStatus.criticalDefects) {
          items.add(
            const PurchaseChecklistItem(
              code: 'TECHNICAL_CONTROL',
              title: 'Contrôle technique',
              detail:
                  'Une défaillance critique est déclarée. Ne roulez pas sans réparation.',
              level: PurchaseCheckLevel.blocking,
            ),
          );
        } else if (profile.technicalControlStatus ==
            PurchaseTechnicalControlStatus.majorDefects) {
          items.add(
            PurchaseChecklistItem(
              code: 'TECHNICAL_CONTROL',
              title: 'Contrôle technique',
              detail:
                  'Des défaillances majeures sont présentes. Chiffrez les réparations avant le '
                  '${_formatDate(technicalControlExpiresAt)}.',
              level: PurchaseCheckLevel.warning,
            ),
          );
        } else {
          items.add(
            PurchaseChecklistItem(
              code: 'TECHNICAL_CONTROL',
              title: 'Contrôle technique',
              detail:
                  'Le contrôle favorable reste valable jusqu’au '
                  '${_formatDate(technicalControlExpiresAt)}.',
              level: PurchaseCheckLevel.ready,
            ),
          );
        }
      }
    }

    items.add(
      PurchaseChecklistItem(
        code: 'HISTOVEC',
        title: 'Rapport HistoVec',
        detail: profile.histovecReviewed
            ? 'Le rapport a été consulté et comparé aux informations du véhicule.'
            : 'Demandez au vendeur de partager le rapport officiel avant le rendez-vous.',
        level: profile.histovecReviewed
            ? PurchaseCheckLevel.ready
            : PurchaseCheckLevel.warning,
      ),
    );
    _addBinary(
      items,
      code: 'MILEAGE_HISTORY',
      title: 'Historique du kilométrage',
      ready: profile.mileageHistoryCoherent,
      readyDetail:
          'Le kilométrage paraît cohérent avec les documents disponibles.',
      blockingDetail:
          'Une incohérence de kilométrage doit être expliquée et documentée.',
    );
    items.add(
      PurchaseChecklistItem(
        code: 'MAINTENANCE',
        title: 'Entretien et factures',
        detail: profile.maintenanceEvidence
            ? 'Des justificatifs d’entretien sont disponibles.'
            : 'Demandez les factures et prévoyez une réserve plus importante.',
        level: profile.maintenanceEvidence
            ? PurchaseCheckLevel.ready
            : PurchaseCheckLevel.optional,
      ),
    );
    items.add(
      PurchaseChecklistItem(
        code: 'COLD_START',
        title: 'Démarrage à froid',
        detail: profile.coldStartObserved
            ? 'Le démarrage à froid a pu être observé.'
            : 'Demandez que le moteur soit froid lors de votre arrivée.',
        level: profile.coldStartObserved
            ? PurchaseCheckLevel.ready
            : PurchaseCheckLevel.warning,
      ),
    );
    items.add(
      PurchaseChecklistItem(
        code: 'WARNING_LIGHTS',
        title: 'Voyants et messages',
        detail: profile.warningLightsClear
            ? 'Aucun voyant persistant n’a été relevé.'
            : 'Un voyant ou un message doit être diagnostiqué avant l’achat.',
        level: profile.warningLightsClear
            ? PurchaseCheckLevel.ready
            : PurchaseCheckLevel.warning,
      ),
    );
    items.add(
      PurchaseChecklistItem(
        code: 'TEST_DRIVE',
        title: 'Essai routier',
        detail: profile.testDriveCompleted
            ? 'Un essai routier a été réalisé.'
            : 'N’achetez pas sans essai routier, sauf expertise indépendante.',
        level: profile.testDriveCompleted
            ? PurchaseCheckLevel.ready
            : PurchaseCheckLevel.warning,
      ),
    );
    _addBinary(
      items,
      code: 'BRAKING_STEERING',
      title: 'Freinage et direction',
      ready: profile.brakingSteeringHealthy,
      readyDetail: 'Aucune anomalie évidente de freinage ou de direction.',
      blockingDetail:
          'Une anomalie de freinage ou de direction impose un contrôle professionnel.',
    );

    if (profile.bodyStructureConcern) {
      items.add(
        const PurchaseChecklistItem(
          code: 'STRUCTURE',
          title: 'Structure et carrosserie',
          detail:
              'Un doute sur la structure, les soudures ou les alignements impose une expertise.',
          level: PurchaseCheckLevel.blocking,
        ),
      );
    } else {
      items.add(
        const PurchaseChecklistItem(
          code: 'STRUCTURE',
          title: 'Structure et carrosserie',
          detail: 'Aucun signal structurel préoccupant n’a été déclaré.',
          level: PurchaseCheckLevel.ready,
        ),
      );
    }

    items.add(
      PurchaseChecklistItem(
        code: 'LEAKS_SMOKE',
        title: 'Fuites et fumées',
        detail: profile.leaksOrSmokeDetected
            ? 'Une fuite ou une fumée anormale doit être diagnostiquée.'
            : 'Aucune fuite ou fumée anormale n’a été déclarée.',
        level: profile.leaksOrSmokeDetected
            ? PurchaseCheckLevel.warning
            : PurchaseCheckLevel.ready,
      ),
    );

    if (profile.depositBeforeChecks) {
      items.add(
        const PurchaseChecklistItem(
          code: 'DEPOSIT',
          title: 'Acompte avant vérifications',
          detail:
              'Ne versez pas d’acompte irréversible avant les contrôles et les documents.',
          level: PurchaseCheckLevel.blocking,
        ),
      );
    }
    items.add(
      PurchaseChecklistItem(
        code: 'PAYMENT',
        title: 'Paiement',
        detail: profile.securePaymentPlanned
            ? 'Le moyen de paiement et la remise du véhicule sont préparés.'
            : 'Convenez d’un paiement traçable et vérifiable avec votre banque.',
        level: profile.securePaymentPlanned
            ? PurchaseCheckLevel.ready
            : PurchaseCheckLevel.warning,
      ),
    );

    final totalAcquisitionCost =
        profile.askingPrice +
        profile.registrationCost +
        profile.immediateRepairBudget +
        profile.inspectionCost;
    final remainingBudget = profile.availableBudget - totalAcquisitionCost;
    if (profile.availableBudget <= 0) {
      items.add(
        const PurchaseChecklistItem(
          code: 'BUDGET',
          title: 'Budget total',
          detail: 'Renseignez votre budget maximum pour mesurer votre marge.',
          level: PurchaseCheckLevel.warning,
        ),
      );
    } else if (remainingBudget < 0) {
      items.add(
        PurchaseChecklistItem(
          code: 'BUDGET',
          title: 'Budget total',
          detail:
              'Le coût total dépasse le budget de ${_money(-remainingBudget)}.',
          level: PurchaseCheckLevel.blocking,
        ),
      );
    } else {
      items.add(
        PurchaseChecklistItem(
          code: 'BUDGET',
          title: 'Budget total',
          detail: 'Une marge de ${_money(remainingBudget)} reste disponible.',
          level: remainingBudget >= profile.immediateRepairBudget
              ? PurchaseCheckLevel.ready
              : PurchaseCheckLevel.warning,
        ),
      );
    }

    final blockingCount = items
        .where((item) => item.level == PurchaseCheckLevel.blocking)
        .length;
    final warningCount = items
        .where((item) => item.level == PurchaseCheckLevel.warning)
        .length;
    final optionalCount = items
        .where((item) => item.level == PurchaseCheckLevel.optional)
        .length;
    final score = clampScore(
      100 - blockingCount * 18 - warningCount * 7 - optionalCount * 2,
    );
    final decisionLevel = blockingCount > 0
        ? PurchaseDecisionLevel.stop
        : warningCount > 2
        ? PurchaseDecisionLevel.caution
        : PurchaseDecisionLevel.ready;

    return UsedPurchaseAssessment(
      score: score,
      decisionLevel: decisionLevel,
      blockingCount: blockingCount,
      warningCount: warningCount,
      totalAcquisitionCost: totalAcquisitionCost,
      remainingBudget: remainingBudget,
      items: List.unmodifiable(items),
      technicalControlRequired: technicalControlRequired,
      csaExpiresAt: csaExpiresAt,
      technicalControlExpiresAt: technicalControlExpiresAt,
    );
  }

  static void _addBinary(
    List<PurchaseChecklistItem> items, {
    required String code,
    required String title,
    required bool ready,
    required String readyDetail,
    required String blockingDetail,
  }) {
    items.add(
      PurchaseChecklistItem(
        code: code,
        title: title,
        detail: ready ? readyDetail : blockingDetail,
        level: ready ? PurchaseCheckLevel.ready : PurchaseCheckLevel.blocking,
      ),
    );
  }

  static DateTime _addCalendarDays(DateTime value, int days) {
    final date = _dateOnly(value);
    final utc = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: days));
    return DateTime(utc.year, utc.month, utc.day);
  }

  static DateTime _addCalendarMonths(DateTime value, int months) {
    final date = _dateOnly(value);
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  static String _money(double value) => '${value.toStringAsFixed(2)} €';
}
