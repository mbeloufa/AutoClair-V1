import 'theft_assistant_models.dart';

class TheftAssistantCalculator {
  const TheftAssistantCalculator._();

  static TheftAssessment assess({
    required TheftAssistantProfile profile,
    required TheftCaseInput input,
    DateTime? now,
  }) {
    profile.validate();
    input.validate(now: now);

    final reference = _dateOnly(now ?? DateTime.now());
    final incidentDate = _dateOnly(input.occurredAt);
    final theftDeadline = input.incidentType.usesTheftDeadline;
    final declarationDueDate = _addWorkingDays(
      incidentDate,
      theftDeadline ? 2 : 5,
    );
    final emergencyRequired = input.incidentInProgress;
    final onlineComplaintEligible =
        !input.authorKnown && !input.incidentInProgress;

    final actionLevel = switch ((
      emergencyRequired,
      input.incidentType == TheftIncidentType.vehicleTheft &&
          input.vehicleMissing &&
          !input.impoundChecked,
      input.policeReported,
      input.insurerNotified,
    )) {
      (true, _, _, _) => TheftActionLevel.emergency,
      (false, true, _, _) => TheftActionLevel.checkImpound,
      (false, false, false, _) => TheftActionLevel.policeReport,
      (false, false, true, false) => TheftActionLevel.insurerDeclaration,
      _ => TheftActionLevel.followUp,
    };

    final items = <TheftChecklistItem>[];

    if (input.incidentInProgress) {
      items.add(
        const TheftChecklistItem(
          code: 'EMERGENCY',
          title: 'Ne pas intervenir',
          detail:
              'Éloignez-vous, ne confrontez personne et appelez immédiatement le 17.',
          level: TheftCheckLevel.blocking,
        ),
      );
    }

    if (input.incidentType == TheftIncidentType.vehicleTheft &&
        input.vehicleMissing) {
      items.add(
        TheftChecklistItem(
          code: 'IMPOUND',
          title: 'Vérifier la fourrière',
          detail: input.impoundChecked
              ? 'La mise en fourrière est indiquée comme vérifiée.'
              : 'Avant de déclarer le vol, vérifiez que le véhicule n’a pas été mis en fourrière.',
          level: input.impoundChecked
              ? TheftCheckLevel.ready
              : TheftCheckLevel.blocking,
        ),
      );
    }

    items.add(
      TheftChecklistItem(
        code: 'POLICE_REPORT',
        title: 'Déposer plainte rapidement',
        detail: input.policeReported
            ? 'La plainte est indiquée comme déposée.'
            : input.authorKnown
            ? 'L’auteur est indiqué comme connu : déposez plainte sur place ou par courrier.'
            : 'L’auteur est inconnu : la plainte en ligne peut être utilisée si la situation n’est plus en cours.',
        level: input.policeReported
            ? TheftCheckLevel.ready
            : TheftCheckLevel.blocking,
      ),
    );

    items.add(
      TheftChecklistItem(
        code: 'RECEIPT',
        title: 'Conserver le récépissé',
        detail: input.complaintReceiptAvailable
            ? 'Le récépissé de plainte est indiqué comme disponible.'
            : 'Demandez et conservez le récépissé ou la copie de la plainte pour l’assureur.',
        level: input.complaintReceiptAvailable
            ? TheftCheckLevel.ready
            : TheftCheckLevel.warning,
      ),
    );

    final overdue = reference.isAfter(declarationDueDate);
    items.add(
      TheftChecklistItem(
        code: 'INSURER',
        title: 'Prévenir l’assureur',
        detail: input.insurerNotified
            ? 'L’assureur est indiqué comme prévenu.'
            : theftDeadline
            ? 'Déclarez le sinistre dans le délai du contrat, qui ne peut être inférieur à deux jours ouvrés en cas de vol.'
            : 'Déclarez le sinistre dans le délai du contrat, qui ne peut être inférieur à cinq jours ouvrés pour un sinistre hors vol.',
        level: input.insurerNotified
            ? TheftCheckLevel.ready
            : overdue
            ? TheftCheckLevel.blocking
            : TheftCheckLevel.warning,
      ),
    );

    items.add(
      TheftChecklistItem(
        code: 'EVIDENCE',
        title: 'Préserver les preuves',
        detail: input.photosTaken
            ? 'Les photos sont indiquées comme réalisées.'
            : input.contextType == TheftContextType.home
            ? 'Ne touchez pas aux accès ou objets déplacés avant les constatations si les forces de l’ordre interviennent.'
            : 'Photographiez les dégradations, traces et pièces manquantes sans modifier la scène.',
        level: input.photosTaken
            ? TheftCheckLevel.ready
            : TheftCheckLevel.warning,
      ),
    );

    if (input.incidentType == TheftIncidentType.vehicleTheft) {
      items.add(
        TheftChecklistItem(
          code: 'KEYS',
          title: 'Rassembler les clés',
          detail:
              '${input.keysAvailableCount} clé(s) indiquée(s). L’assureur peut demander les clés disponibles et le certificat d’immatriculation.',
          level: input.keysAvailableCount >= 2
              ? TheftCheckLevel.ready
              : TheftCheckLevel.warning,
        ),
      );
    }

    if (input.registrationDocumentStolen ||
        input.insuranceDocumentsStolen ||
        input.drivingLicenceStolen) {
      final stolen = <String>[
        if (input.registrationDocumentStolen) 'certificat d’immatriculation',
        if (input.insuranceDocumentsStolen) 'documents d’assurance',
        if (input.drivingLicenceStolen) 'permis de conduire',
      ];
      items.add(
        TheftChecklistItem(
          code: 'DOCUMENTS',
          title: 'Signaler les documents volés',
          detail:
              'Mentionnez dans la plainte : ${stolen.join(', ')}. Conservez les récépissés pour les duplicatas.',
          level: TheftCheckLevel.warning,
        ),
      );
    }

    if (profile.trackerAvailable &&
        input.vehicleMissing &&
        !input.vehicleFound) {
      items.add(
        TheftChecklistItem(
          code: 'TRACKER',
          title: 'Traceur antivol',
          detail: input.trackerDeclaredToPolice
              ? 'Le traceur est indiqué comme signalé aux forces de l’ordre.'
              : 'Indiquez l’existence du traceur aux forces de l’ordre. Ne tentez pas de récupérer seul le véhicule.',
          level: input.trackerDeclaredToPolice
              ? TheftCheckLevel.ready
              : TheftCheckLevel.warning,
        ),
      );
    }

    if (input.incidentType == TheftIncidentType.plateTheft) {
      items.add(
        const TheftChecklistItem(
          code: 'PLATE',
          title: 'Faire remplacer la plaque',
          detail:
              'Après la plainte, faites fabriquer et poser une plaque conforme avant de circuler.',
          level: TheftCheckLevel.warning,
        ),
      );
    }

    if (!profile.theftCoverageKnown) {
      items.add(
        const TheftChecklistItem(
          code: 'COVERAGE',
          title: 'Vérifier les garanties',
          detail:
              'La responsabilité civile seule ne couvre pas nécessairement les dommages au véhicule. Vérifiez vol, tentative, vandalisme, contenu et accessoires.',
          level: TheftCheckLevel.information,
        ),
      );
    }

    if (!input.invoicesAvailable) {
      items.add(
        const TheftChecklistItem(
          code: 'INVOICES',
          title: 'Rassembler les justificatifs',
          detail:
              'Préparez factures d’achat, équipements, réparations, entretien et éléments permettant d’établir la valeur du véhicule.',
          level: TheftCheckLevel.information,
        ),
      );
    }

    if (input.vehicleFound) {
      items.add(
        const TheftChecklistItem(
          code: 'FOUND',
          title: 'Véhicule retrouvé',
          detail:
              'Prévenez les forces de l’ordre et l’assureur avant de reprendre le véhicule. Faites contrôler son état et les éventuelles traces.',
          level: TheftCheckLevel.warning,
        ),
      );
    }

    return TheftAssessment(
      actionLevel: actionLevel,
      score: _score(items),
      emergencyRequired: emergencyRequired,
      onlineComplaintEligible: onlineComplaintEligible,
      declarationDueDate: declarationDueDate,
      items: List.unmodifiable(items),
      evidenceSuggestions: const [
        'Vue générale du véhicule ou de son emplacement',
        'Serrures, vitres, neiman et traces d’effraction',
        'Éléments manquants ou dégradés',
        'Clés disponibles, factures et équipements déclarés',
      ],
    );
  }

  static int _score(List<TheftChecklistItem> items) {
    var score = 100;
    for (final item in items) {
      score -= switch (item.level) {
        TheftCheckLevel.blocking => 25,
        TheftCheckLevel.warning => 8,
        TheftCheckLevel.ready || TheftCheckLevel.information => 0,
      };
    }
    return score.clamp(0, 100).toInt();
  }

  static DateTime _addWorkingDays(DateTime value, int workingDays) {
    var current = _dateOnly(value);
    var added = 0;
    while (added < workingDays) {
      current = _addCalendarDays(current, 1);
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        added++;
      }
    }
    return current;
  }

  static DateTime _addCalendarDays(DateTime value, int days) {
    final local = _dateOnly(value);
    final utc = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).add(Duration(days: days));
    return DateTime(utc.year, utc.month, utc.day);
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
