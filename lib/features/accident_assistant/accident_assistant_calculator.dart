import 'accident_assistant_models.dart';

class AccidentAssistantCalculator {
  static AccidentAssessment assess({
    required AccidentCaseInput input,
    DateTime? now,
  }) {
    input.validate(now: now);
    final reference = _dateOnly(now ?? DateTime.now());
    final accidentDate = _dateOnly(input.occurredAt);
    final emergencyRequired = input.injured || input.immediateDanger;
    final eConstatEligible =
        !emergencyRequired &&
        input.materialDamageOnly &&
        input.vehicleCount <= 2 &&
        !input.foreignVehicle &&
        !input.otherPartyRefused;
    final paperReportRequired =
        !eConstatEligible &&
        (input.injured ||
            !input.materialDamageOnly ||
            input.vehicleCount > 2 ||
            input.foreignVehicle ||
            input.otherPartyRefused);

    final actionLevel = emergencyRequired
        ? AccidentActionLevel.emergency
        : paperReportRequired
        ? AccidentActionLevel.paperReport
        : eConstatEligible
        ? AccidentActionLevel.electronicReport
        : AccidentActionLevel.insurerDeclaration;

    final items = <AccidentChecklistItem>[];

    if (emergencyRequired) {
      items.add(
        AccidentChecklistItem(
          code: 'EMERGENCY',
          title: 'Prévenir les secours',
          detail: input.emergencyCalled
              ? 'L’appel aux secours est indiqué comme réalisé.'
              : 'Appelez immédiatement le 112. Le 17 peut aussi joindre la police ou la gendarmerie.',
          level: input.emergencyCalled
              ? AccidentCheckLevel.ready
              : AccidentCheckLevel.blocking,
        ),
      );
      items.add(
        const AccidentChecklistItem(
          code: 'INJURED_PERSON',
          title: 'Protéger les personnes',
          detail:
              'Ne déplacez pas une personne blessée, sauf danger immédiat. Suivez les consignes des secours.',
          level: AccidentCheckLevel.blocking,
        ),
      );
    } else {
      items.add(
        const AccidentChecklistItem(
          code: 'SAFETY',
          title: 'Sécuriser avant le constat',
          detail:
              'Mettez les personnes à l’abri et ne prenez des photos que si cela peut être fait sans danger.',
          level: AccidentCheckLevel.information,
        ),
      );
    }

    if (input.locationType == AccidentLocationType.motorway) {
      items.add(
        const AccidentChecklistItem(
          code: 'MOTORWAY',
          title: 'Autoroute ou voie rapide',
          detail:
              'Sortez si possible côté passager, placez-vous derrière la glissière et n’installez pas de triangle sur autoroute.',
          level: AccidentCheckLevel.blocking,
        ),
      );
    }

    if (eConstatEligible) {
      items.add(
        const AccidentChecklistItem(
          code: 'REPORT_METHOD',
          title: 'E-constat possible',
          detail:
              'Le scénario déclaré concerne au maximum deux véhicules assurés en France, sans dommage corporel.',
          level: AccidentCheckLevel.ready,
        ),
      );
    } else if (paperReportRequired) {
      final reason = _paperReason(input);
      items.add(
        AccidentChecklistItem(
          code: 'REPORT_METHOD',
          title: 'Utiliser un constat papier',
          detail: reason,
          level: AccidentCheckLevel.warning,
        ),
      );
    } else {
      items.add(
        const AccidentChecklistItem(
          code: 'REPORT_METHOD',
          title: 'Contacter l’assureur',
          detail:
              'Décrivez les faits à votre assureur et suivez la méthode de déclaration prévue par votre contrat.',
          level: AccidentCheckLevel.warning,
        ),
      );
    }

    items.add(
      AccidentChecklistItem(
        code: 'MEMO',
        title: 'Mémo Véhicule Assuré',
        detail: input.memoAvailable
            ? 'Les informations principales du contrat sont disponibles.'
            : 'Retrouvez le Mémo Véhicule Assuré ou les informations du contrat.',
        level: input.memoAvailable
            ? AccidentCheckLevel.ready
            : AccidentCheckLevel.warning,
      ),
    );
    items.add(
      AccidentChecklistItem(
        code: 'PHOTOS',
        title: 'Photos factuelles',
        detail: input.photosTaken
            ? 'Les photos utiles sont indiquées comme réalisées.'
            : 'Photographiez la vue générale, les dommages et la signalisation, uniquement si la situation est sûre.',
        level: input.photosTaken
            ? AccidentCheckLevel.ready
            : AccidentCheckLevel.warning,
      ),
    );
    items.add(
      AccidentChecklistItem(
        code: 'SKETCH',
        title: 'Croquis et circonstances',
        detail: input.sketchPrepared
            ? 'Le croquis et les circonstances sont préparés.'
            : 'Préparez un croquis simple avec voies, sens, panneaux et points de choc.',
        level: input.sketchPrepared
            ? AccidentCheckLevel.ready
            : AccidentCheckLevel.warning,
      ),
    );
    items.add(
      AccidentChecklistItem(
        code: 'WITNESSES',
        title: 'Témoins éventuels',
        detail: input.witnessesPresent
            ? 'Conservez les coordonnées des témoins dans le constat ou le dossier assureur, pas dans AutoClair.'
            : 'Indiquez dans le constat s’il n’y a aucun témoin indépendant.',
        level: AccidentCheckLevel.information,
      ),
    );

    if (input.otherPartyRefused) {
      items.add(
        const AccidentChecklistItem(
          code: 'REFUSAL',
          title: 'Refus ou désaccord',
          detail:
              'Ne modifiez pas les faits pour obtenir une signature. Remplissez votre déclaration et signalez le refus à l’assureur.',
          level: AccidentCheckLevel.warning,
        ),
      );
    }

    items.add(
      AccidentChecklistItem(
        code: 'SIGNATURE',
        title: 'Vérifier avant de signer',
        detail: input.reportSigned
            ? 'Le constat est indiqué comme signé.'
            : 'Relisez toutes les cases, le croquis et les observations avant toute signature.',
        level: input.reportSigned
            ? AccidentCheckLevel.ready
            : AccidentCheckLevel.warning,
      ),
    );
    items.add(
      AccidentChecklistItem(
        code: 'INSURER',
        title: 'Déclarer le sinistre',
        detail: input.insurerNotified
            ? 'L’assureur est indiqué comme prévenu.'
            : 'Transmettez rapidement le constat ou la déclaration, au plus tard dans le délai prévu par le contrat.',
        level: input.insurerNotified
            ? AccidentCheckLevel.ready
            : AccidentCheckLevel.warning,
      ),
    );

    if (accidentDate.isAfter(reference)) {
      items.add(
        const AccidentChecklistItem(
          code: 'DATE',
          title: 'Date de l’accident',
          detail: 'La date saisie est dans le futur.',
          level: AccidentCheckLevel.blocking,
        ),
      );
    }

    final score = _score(items);
    return AccidentAssessment(
      actionLevel: actionLevel,
      score: score,
      emergencyRequired: emergencyRequired,
      eConstatEligible: eConstatEligible,
      paperReportRequired: paperReportRequired,
      declarationDueDate: _addWorkingDays(accidentDate, 5),
      items: List.unmodifiable(items),
      photoSuggestions: const [
        'Vue générale des véhicules et de la chaussée',
        'Dommages de chaque côté du véhicule',
        'Marquage au sol, panneaux et feux',
        'Débris ou traces visibles, sans se mettre en danger',
      ],
    );
  }

  static String _paperReason(AccidentCaseInput input) {
    if (input.injured || !input.materialDamageOnly) {
      return 'Un dommage corporel est déclaré : utilisez un constat papier en complément des démarches de secours.';
    }
    if (input.vehicleCount > 2) {
      return 'Plus de deux véhicules sont impliqués : utilisez un constat papier pour chaque relation utile.';
    }
    if (input.foreignVehicle) {
      return 'Un véhicule étranger est impliqué : utilisez un constat papier.';
    }
    if (input.otherPartyRefused) {
      return 'L’autre partie refuse ou conteste la signature : préparez votre propre déclaration pour l’assureur.';
    }
    return 'Le scénario déclaré ne correspond pas aux conditions usuelles du e-constat.';
  }

  static int _score(List<AccidentChecklistItem> items) {
    var score = 100;
    for (final item in items) {
      score -= switch (item.level) {
        AccidentCheckLevel.blocking => 25,
        AccidentCheckLevel.warning => 8,
        AccidentCheckLevel.ready || AccidentCheckLevel.information => 0,
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
