class UsedListingFinding {
  const UsedListingFinding({required this.title, required this.detail});

  final String title;
  final String detail;
}

class UsedListingAnalysis {
  const UsedListingAnalysis({
    required this.detectedYear,
    required this.detectedMileage,
    required this.detectedPrice,
    required this.mentionedEvidence,
    required this.findings,
    required this.questions,
    required this.missingEssentials,
  });

  final int? detectedYear;
  final int? detectedMileage;
  final double? detectedPrice;
  final List<String> mentionedEvidence;
  final List<UsedListingFinding> findings;
  final List<String> questions;
  final List<String> missingEssentials;

  bool get hasPointsToCheck =>
      findings.isNotEmpty || missingEssentials.isNotEmpty;
}

abstract final class UsedListingAnalyzer {
  static UsedListingAnalysis analyze(String source, {DateTime? now}) {
    final text = source.trim();
    if (text.isEmpty) {
      return const UsedListingAnalysis(
        detectedYear: null,
        detectedMileage: null,
        detectedPrice: null,
        mentionedEvidence: [],
        findings: [],
        questions: [],
        missingEssentials: ['année', 'kilométrage', 'prix'],
      );
    }

    final folded = _fold(text);
    final detectedYear = _extractYear(text, now: now);
    final detectedMileage = _extractMileage(text);
    final detectedPrice = _extractPrice(text);

    final evidence = <String>[];
    final findings = <UsedListingFinding>[];
    final questions = <String>[];

    final mentionsTechnicalControl =
        _containsAny(folded, const ['controle technique']) ||
        RegExp(r'\bct\b').hasMatch(folded);
    final mentionsHistovec = folded.contains('histovec');
    final mentionsMaintenance = _containsAny(folded, const [
      'facture',
      'factures',
      'carnet entretien',
      'carnet d entretien',
      'entretien suivi',
      'revision',
    ]);

    if (mentionsTechnicalControl) {
      evidence.add('Contrôle technique mentionné');
    }
    if (mentionsHistovec) {
      evidence.add('HistoVec mentionné');
    }
    if (mentionsMaintenance) {
      evidence.add('Entretien ou justificatifs mentionnés');
    }
    if (folded.contains('garantie')) {
      evidence.add('Garantie mentionnée');
    }

    final technicalControlConcern = _containsAny(folded, const [
      'sans ct',
      'ct a faire',
      'controle technique a faire',
      'controle technique non fait',
      'controle technique expire',
      'ct expire',
    ]);
    if (technicalControlConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'Contrôle technique à vérifier',
          detail:
              'L’annonce indique qu’il est absent, à réaliser ou potentiellement expiré.',
        ),
      );
      _addUnique(
        questions,
        'Pouvez-vous envoyer le dernier procès-verbal complet du contrôle technique ?',
      );
    }

    final mileageConcern = _containsAny(folded, const [
      'kilometrage non garanti',
      'kilometrage non certifie',
      'compteur change',
      'compteur remplace',
    ]);
    if (mileageConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'Kilométrage à documenter',
          detail:
              'L’annonce contient une réserve sur le kilométrage ou le compteur.',
        ),
      );
      _addUnique(
        questions,
        'Pouvez-vous expliquer l’historique du kilométrage et fournir les justificatifs correspondants ?',
      );
    }

    final majorMechanicalConcern = _containsAny(folded, const [
      'moteur hs',
      'boite hs',
      'boite de vitesse hs',
      'pour pieces',
      'non roulant',
      'non roulante',
    ]);
    if (majorMechanicalConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'État mécanique fortement dégradé mentionné',
          detail:
              'L’annonce emploie des termes indiquant une panne importante ou un véhicule non roulant.',
        ),
      );
      _addUnique(
        questions,
        'Quel diagnostic professionnel existe pour la panne mentionnée et quel devis de réparation est disponible ?',
      );
    }

    final anomalyConcern = _containsAny(folded, const [
      'voyant moteur',
      'voyant allume',
      'fuite',
      'fumee',
      'bruit anormal',
      'bruit moteur',
    ]);
    if (anomalyConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'Anomalie technique mentionnée',
          detail:
              'Un voyant, une fuite, une fumée ou un bruit est évoqué. Faites-le diagnostiquer avant l’achat.',
        ),
      );
      _addUnique(
        questions,
        'Quel diagnostic a été réalisé pour l’anomalie signalée et pouvez-vous transmettre le compte rendu ou le devis ?',
      );
    }

    final plannedWorkConcern = _containsAny(folded, const [
      'travaux a prevoir',
      'frais a prevoir',
      'reparation a prevoir',
      'reparations a prevoir',
    ]);
    if (plannedWorkConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'Travaux annoncés',
          detail:
              'L’annonce signale des frais ou réparations à prévoir sans en confirmer le coût réel.',
        ),
      );
      _addUnique(
        questions,
        'Quels travaux sont exactement à prévoir et existe-t-il un devis récent ?',
      );
    }

    final maintenanceConcern = _containsAny(folded, const [
      'pas de facture',
      'aucune facture',
      'sans facture',
      'carnet perdu',
      'sans carnet',
    ]);
    if (maintenanceConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'Entretien peu documenté',
          detail:
              'L’annonce indique que des justificatifs d’entretien sont absents ou incomplets.',
        ),
      );
    }

    final paymentConcern = _containsAny(folded, const [
      'western union',
      'mandat cash',
      'virement avant visite',
      'paiement avant visite',
      'acompte pour reserver',
      'acompte pour réserver',
      'reservation par acompte',
      'réservation par acompte',
    ]);
    if (paymentConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'Paiement ou réservation à sécuriser',
          detail:
              'L’annonce évoque un paiement ou un acompte avant la vérification du véhicule.',
        ),
      );
      _addUnique(
        questions,
        'Puis-je vérifier le véhicule, son identité et ses documents avant tout versement ?',
      );
    }

    final pressureConcern = _containsAny(folded, const [
      'vente urgente',
      'urgent a vendre',
      'premier arrive premier servi',
      'pas de temps a perdre',
    ]);
    if (pressureConcern) {
      findings.add(
        const UsedListingFinding(
          title: 'Pression temporelle mentionnée',
          detail:
              'Une vente urgente n’est pas une preuve d’arnaque, mais ne doit pas raccourcir vos vérifications.',
        ),
      );
    }

    if (!mentionsTechnicalControl) {
      _addUnique(
        questions,
        'Pouvez-vous envoyer le dernier procès-verbal complet du contrôle technique ?',
      );
    }
    if (!mentionsHistovec) {
      _addUnique(
        questions,
        'Pouvez-vous partager le rapport HistoVec du véhicule avant le rendez-vous ?',
      );
    }
    if (!mentionsMaintenance) {
      _addUnique(
        questions,
        'Quels justificatifs d’entretien et quelles factures pouvez-vous transmettre ?',
      );
    }

    final missing = <String>[
      if (detectedYear == null) 'année',
      if (detectedMileage == null) 'kilométrage',
      if (detectedPrice == null) 'prix',
    ];

    return UsedListingAnalysis(
      detectedYear: detectedYear,
      detectedMileage: detectedMileage,
      detectedPrice: detectedPrice,
      mentionedEvidence: List.unmodifiable(evidence),
      findings: List.unmodifiable(findings),
      questions: List.unmodifiable(questions.take(6)),
      missingEssentials: List.unmodifiable(missing),
    );
  }

  static int? _extractYear(String source, {DateTime? now}) {
    final currentYear = (now ?? DateTime.now()).year;
    final matches = RegExp(r'\b(?:19|20)\d{2}\b').allMatches(source);
    for (final match in matches) {
      final value = int.tryParse(match.group(0)!);
      if (value != null && value >= 1950 && value <= currentYear + 1) {
        return value;
      }
    }
    return null;
  }

  static int? _extractMileage(String source) {
    final match = RegExp(
      r'(\d{1,3}(?:[ \u00a0]\d{3})+|\d{4,7})\s*(?:km|kms|kilom[eè]tres?)\b',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) return null;
    return int.tryParse(match.group(1)!.replaceAll(RegExp(r'[ \u00a0]'), ''));
  }

  static double? _extractPrice(String source) {
    final match = RegExp(
      r'(\d{1,3}(?:[ \u00a0]\d{3})+|\d{3,7})(?:,(\d{1,2}))?\s*(?:€|eur(?:os?)?)(?!\w)',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) return null;

    final whole = match.group(1)!.replaceAll(RegExp(r'[ \u00a0]'), '');
    final decimals = match.group(2);
    return double.tryParse(decimals == null ? whole : '$whole.$decimals');
  }

  static bool _containsAny(String source, List<String> patterns) {
    return patterns.any((pattern) => source.contains(_fold(pattern)));
  }

  static void _addUnique(List<String> values, String value) {
    if (!values.contains(value)) values.add(value);
  }

  static String _fold(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâäãå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[òóôöõ]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll('œ', 'oe')
        .replaceAll('æ', 'ae')
        .replaceAll('’', ' ')
        .replaceAll("'", ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
