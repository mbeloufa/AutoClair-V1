import 'dart:math' as math;

import '../vehicles/vehicle.dart';
import 'sale_preparation_models.dart';

class SalePreparationCalculator {
  SalePreparationCalculator._();

  static SalePreparationAssessment assess({
    required Vehicle vehicle,
    required SalePreparationProfile profile,
    required SalePreparationContext context,
    DateTime? now,
  }) {
    profile.validate();
    final reference = _dateOnly(now ?? DateTime.now());
    final items = <SaleChecklistItem>[];

    _add(
      items,
      code: 'OWNERSHIP',
      title: 'Propriété du véhicule',
      ready: profile.ownsVehicle,
      blockingDetail:
          'Un véhicule en LOA ou appartenant à un tiers ne peut pas être '
          'vendu directement par l’utilisateur.',
      readyDetail: 'Le vendeur confirme être propriétaire du véhicule.',
    );
    _add(
      items,
      code: 'REGISTRATION',
      title: 'Carte grise disponible',
      ready: profile.registrationAvailable,
      blockingDetail:
          'La carte grise complète doit être disponible pour finaliser '
          'la cession.',
      readyDetail: 'La carte grise est disponible.',
    );
    _add(
      items,
      code: 'COHOLDERS',
      title: 'Signature des cotitulaires',
      ready: profile.coHoldersReady,
      blockingDetail:
          'Tous les cotitulaires mentionnés sur la carte grise doivent '
          'pouvoir signer.',
      readyDetail: 'Les signatures nécessaires sont prévues.',
    );

    if ((vehicle.registrationNumber ?? '').trim().isEmpty) {
      items.add(
        const SaleChecklistItem(
          code: 'VEHICLE_IDENTITY',
          title: 'Immatriculation dans AutoClair',
          detail:
              'Complétez l’immatriculation pour préparer plus facilement '
              'les démarches officielles.',
          level: SaleChecklistLevel.warning,
        ),
      );
    } else {
      items.add(
        const SaleChecklistItem(
          code: 'VEHICLE_IDENTITY',
          title: 'Immatriculation dans AutoClair',
          detail: 'L’immatriculation est renseignée.',
          level: SaleChecklistLevel.ready,
        ),
      );
    }

    final age = vehicle.vehicleYear == null
        ? null
        : reference.year - vehicle.vehicleYear!;
    final privateSale = profile.buyerType == SaleBuyerType.privateIndividual;
    final technicalControlRequired = privateSale && age != null && age >= 4;
    final requirementUncertain = privateSale && age == null;

    DateTime? technicalControlExpiresAt;
    if (!privateSale) {
      items.add(
        const SaleChecklistItem(
          code: 'TECHNICAL_CONTROL',
          title: 'Contrôle technique',
          detail:
              'La vente à un professionnel automobile peut être réalisée '
              'sans contrôle technique remis par le particulier.',
          level: SaleChecklistLevel.ready,
        ),
      );
    } else if (requirementUncertain) {
      items.add(
        const SaleChecklistItem(
          code: 'TECHNICAL_CONTROL',
          title: 'Contrôle technique',
          detail:
              'L’année du véhicule est absente. Vérifiez la date exacte de '
              'première mise en circulation et l’obligation de contrôle.',
          level: SaleChecklistLevel.warning,
        ),
      );
    } else if (!technicalControlRequired) {
      items.add(
        const SaleChecklistItem(
          code: 'TECHNICAL_CONTROL',
          title: 'Contrôle technique',
          detail:
              'Le véhicule paraît avoir moins de quatre ans. Confirmez avec '
              'la date exacte de première mise en circulation.',
          level: SaleChecklistLevel.ready,
        ),
      );
    } else {
      final controlDate = profile.technicalControlDate;
      final status = profile.technicalControlStatus;
      if (status == SaleTechnicalControlStatus.criticalDefects) {
        items.add(
          const SaleChecklistItem(
            code: 'TECHNICAL_CONTROL',
            title: 'Contrôle technique',
            detail:
                'Une défaillance critique doit être réparée et contrôlée '
                'avant une vente à un particulier.',
            level: SaleChecklistLevel.blocking,
          ),
        );
      } else if (controlDate == null ||
          status == SaleTechnicalControlStatus.unknown ||
          status == SaleTechnicalControlStatus.notRequired) {
        items.add(
          const SaleChecklistItem(
            code: 'TECHNICAL_CONTROL',
            title: 'Contrôle technique',
            detail:
                'Renseignez le procès-verbal et son résultat pour vérifier '
                'sa validité.',
            level: SaleChecklistLevel.blocking,
          ),
        );
      } else {
        final validityMonths = status == SaleTechnicalControlStatus.majorDefects
            ? 2
            : 6;
        technicalControlExpiresAt = _addCalendarMonths(
          controlDate,
          validityMonths,
        );
        final expired = technicalControlExpiresAt.isBefore(reference);
        if (expired) {
          items.add(
            SaleChecklistItem(
              code: 'TECHNICAL_CONTROL',
              title: 'Contrôle technique',
              detail:
                  'Le délai utilisable est dépassé depuis le '
                  '${_formatDate(technicalControlExpiresAt)}.',
              level: SaleChecklistLevel.blocking,
            ),
          );
        } else if (status == SaleTechnicalControlStatus.majorDefects) {
          items.add(
            SaleChecklistItem(
              code: 'TECHNICAL_CONTROL',
              title: 'Contrôle technique',
              detail:
                  'La vente en l’état reste à confirmer avant le '
                  '${_formatDate(technicalControlExpiresAt)}. '
                  'L’acheteur devra effectuer la contre-visite.',
              level: SaleChecklistLevel.warning,
            ),
          );
        } else {
          items.add(
            SaleChecklistItem(
              code: 'TECHNICAL_CONTROL',
              title: 'Contrôle technique',
              detail:
                  'Le contrôle favorable reste utilisable jusqu’au '
                  '${_formatDate(technicalControlExpiresAt)}.',
              level: SaleChecklistLevel.ready,
            ),
          );
        }
      }
    }

    DateTime? csaExpiresAt;
    final csaDate = profile.csaIssuedAt;
    if (csaDate == null) {
      items.add(
        const SaleChecklistItem(
          code: 'CSA',
          title: 'Certificat de situation administrative',
          detail:
              'Générez le certificat officiel peu avant la cession. '
              'Il doit dater de moins de quinze jours.',
          level: SaleChecklistLevel.blocking,
        ),
      );
    } else {
      csaExpiresAt = _addCalendarDays(csaDate, 14);
      if (csaDate.isAfter(reference)) {
        items.add(
          const SaleChecklistItem(
            code: 'CSA',
            title: 'Certificat de situation administrative',
            detail: 'La date renseignée est dans le futur.',
            level: SaleChecklistLevel.blocking,
          ),
        );
      } else if (csaExpiresAt.isBefore(reference)) {
        items.add(
          SaleChecklistItem(
            code: 'CSA',
            title: 'Certificat de situation administrative',
            detail:
                'Le certificat a expiré le ${_formatDate(csaExpiresAt)}. '
                'Générez-en un nouveau.',
            level: SaleChecklistLevel.blocking,
          ),
        );
      } else {
        items.add(
          SaleChecklistItem(
            code: 'CSA',
            title: 'Certificat de situation administrative',
            detail:
                'Le certificat reste utilisable jusqu’au '
                '${_formatDate(csaExpiresAt)}.',
            level: SaleChecklistLevel.ready,
          ),
        );
      }
    }

    if (profile.cessionMethod == SaleCessionMethod.undecided) {
      items.add(
        const SaleChecklistItem(
          code: 'CESSION_METHOD',
          title: 'Mode de déclaration',
          detail:
              'Choisissez Simplimmat ou la démarche France Titres avant '
              'le rendez-vous.',
          level: SaleChecklistLevel.warning,
        ),
      );
    } else {
      items.add(
        SaleChecklistItem(
          code: 'CESSION_METHOD',
          title: 'Mode de déclaration',
          detail: '${profile.cessionMethod.label} est retenu.',
          level: SaleChecklistLevel.ready,
        ),
      );
    }

    items.add(
      SaleChecklistItem(
        code: 'HISTOVEC',
        title: 'Rapport HistoVec',
        detail: profile.histovecShared
            ? 'Le rapport officiel est prêt à être partagé.'
            : 'Le rapport gratuit rassure l’acheteur sur l’historique.',
        level: profile.histovecShared
            ? SaleChecklistLevel.ready
            : SaleChecklistLevel.optional,
      ),
    );

    final hasUsefulDocuments =
        profile.invoicesAvailable || context.completedDocumentCount > 0;
    items.add(
      SaleChecklistItem(
        code: 'MAINTENANCE_DOCUMENTS',
        title: 'Carnet et factures',
        detail: hasUsefulDocuments
            ? 'Des documents d’entretien sont disponibles.'
            : 'Ajoutez les factures et justificatifs utiles au dossier.',
        level: hasUsefulDocuments
            ? SaleChecklistLevel.ready
            : SaleChecklistLevel.optional,
      ),
    );

    if (profile.spareKeyCount <= 0) {
      items.add(
        const SaleChecklistItem(
          code: 'SPARE_KEYS',
          title: 'Clés du véhicule',
          detail:
              'Aucune clé n’est déclarée. Vérifiez la remise de la clé '
              'principale et signalez clairement toute absence.',
          level: SaleChecklistLevel.warning,
        ),
      );
    } else {
      items.add(
        SaleChecklistItem(
          code: 'SPARE_KEYS',
          title: 'Clés du véhicule',
          detail: '${profile.spareKeyCount} clé(s) prévue(s) pour la remise.',
          level: profile.spareKeyCount >= 2
              ? SaleChecklistLevel.ready
              : SaleChecklistLevel.optional,
        ),
      );
    }

    if (context.overdueMaintenanceCount > 0) {
      items.add(
        SaleChecklistItem(
          code: 'OVERDUE_MAINTENANCE',
          title: 'Entretiens en retard',
          detail:
              '${context.overdueMaintenanceCount} échéance(s) sont en retard. '
              'Réparez ou informez clairement l’acheteur.',
          level: SaleChecklistLevel.warning,
        ),
      );
    } else {
      items.add(
        const SaleChecklistItem(
          code: 'OVERDUE_MAINTENANCE',
          title: 'Entretiens en retard',
          detail: 'Aucune échéance en retard n’est détectée.',
          level: SaleChecklistLevel.ready,
        ),
      );
    }

    if (profile.askingPrice <= 0) {
      items.add(
        const SaleChecklistItem(
          code: 'PRICE_TARGET',
          title: 'Objectif financier',
          detail: 'Renseignez un prix affiché pour calculer le produit net.',
          level: SaleChecklistLevel.warning,
        ),
      );
    } else {
      items.add(
        const SaleChecklistItem(
          code: 'PRICE_TARGET',
          title: 'Objectif financier',
          detail: 'Le prix affiché et le prix minimum sont cohérents.',
          level: SaleChecklistLevel.ready,
        ),
      );
    }

    final blockingCount = items
        .where((item) => item.level == SaleChecklistLevel.blocking)
        .length;
    final warningCount = items
        .where((item) => item.level == SaleChecklistLevel.warning)
        .length;
    final optionalCount = items
        .where((item) => item.level == SaleChecklistLevel.optional)
        .length;
    final score = math.max(
      0,
      100 - blockingCount * 22 - warningCount * 8 - optionalCount * 3,
    );

    final expectedNetAtAsking = math.max(
      0.0,
      profile.askingPrice - profile.preparationCost,
    );
    final expectedNetAtMinimum = math.max(
      0.0,
      profile.minimumPrice - profile.preparationCost,
    );
    final negotiationMargin = math.max(
      0.0,
      profile.askingPrice - profile.minimumPrice,
    );

    return SalePreparationAssessment(
      score: score,
      items: List.unmodifiable(items),
      blockingCount: blockingCount,
      warningCount: warningCount,
      expectedNetAtAsking: expectedNetAtAsking,
      expectedNetAtMinimum: expectedNetAtMinimum,
      negotiationMargin: negotiationMargin,
      technicalControlRequired: technicalControlRequired,
      technicalControlRequirementUncertain: requirementUncertain,
      technicalControlExpiresAt: technicalControlExpiresAt,
      csaExpiresAt: csaExpiresAt,
    );
  }

  static void _add(
    List<SaleChecklistItem> items, {
    required String code,
    required String title,
    required bool ready,
    required String blockingDetail,
    required String readyDetail,
  }) {
    items.add(
      SaleChecklistItem(
        code: code,
        title: title,
        detail: ready ? readyDetail : blockingDetail,
        level: ready ? SaleChecklistLevel.ready : SaleChecklistLevel.blocking,
      ),
    );
  }

  static DateTime _addCalendarMonths(DateTime value, int months) {
    final date = _dateOnly(value);
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = math.min(date.day, lastDay);
    return DateTime(year, month, day);
  }

  static DateTime _addCalendarDays(DateTime value, int days) {
    final date = _dateOnly(value);
    final utcDate = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: days));
    return DateTime(utcDate.year, utcDate.month, utcDate.day);
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
}
