enum LegalCaseCategory {
  professionalPurchase,
  garageRepair,
  warrantyRefusal,
  consumerMediation,
  other,
}

extension LegalCaseCategoryX on LegalCaseCategory {
  String get dbValue => switch (this) {
    LegalCaseCategory.professionalPurchase => 'professional_purchase',
    LegalCaseCategory.garageRepair => 'garage_repair',
    LegalCaseCategory.warrantyRefusal => 'warranty_refusal',
    LegalCaseCategory.consumerMediation => 'consumer_mediation',
    LegalCaseCategory.other => 'other',
  };

  String get label => switch (this) {
    LegalCaseCategory.professionalPurchase => 'Achat de mon véhicule',
    LegalCaseCategory.garageRepair => 'Garage / réparation',
    LegalCaseCategory.warrantyRefusal => 'Garantie refusée',
    LegalCaseCategory.consumerMediation => 'Réclamation / médiation',
    LegalCaseCategory.other => 'Autre problème',
  };

  String get description => switch (this) {
    LegalCaseCategory.professionalPurchase =>
      'Panne, défaut ou information contestée après un achat professionnel.',
    LegalCaseCategory.garageRepair =>
      'Réparation, intervention ou facture que vous souhaitez clarifier.',
    LegalCaseCategory.warrantyRefusal =>
      'Refus de prise en charge par un vendeur, constructeur ou garant.',
    LegalCaseCategory.consumerMediation =>
      'Préparer une réclamation écrite ou une démarche de médiation.',
    LegalCaseCategory.other =>
      'AutoClair organise le dossier et vérifie si le cas entre dans la V1.',
  };
}

class LegalVehicleOption {
  const LegalVehicleOption({
    required this.id,
    required this.displayName,
    this.registrationNumber,
    this.mileage,
    this.year,
  });

  final String id;
  final String displayName;
  final String? registrationNumber;
  final int? mileage;
  final int? year;

  factory LegalVehicleOption.fromMap(Map<String, dynamic> map) {
    final nickname = (map['nickname'] as String?)?.trim();
    final make = (map['make'] as String? ?? '').trim();
    final model = (map['model'] as String? ?? '').trim();
    final fallback = '$make $model'.trim();
    return LegalVehicleOption(
      id: map['id'].toString(),
      displayName: nickname?.isNotEmpty == true ? nickname! : fallback,
      registrationNumber: (map['registration_number'] as String?)?.trim(),
      mileage: (map['mileage'] as num?)?.round(),
      year: (map['vehicle_year'] as num?)?.round(),
    );
  }
}

class LegalDocumentOption {
  const LegalDocumentOption({
    required this.id,
    required this.label,
    required this.status,
    required this.documentType,
  });

  final String id;
  final String label;
  final String status;
  final String documentType;

  bool get analyzed => status.toLowerCase() == 'completed';

  factory LegalDocumentOption.fromMap(Map<String, dynamic> map) {
    final type = (map['document_type'] as String? ?? 'document').trim();
    final comment = (map['comment'] as String?)?.trim();
    return LegalDocumentOption(
      id: map['id'].toString(),
      label: comment?.isNotEmpty == true ? comment! : _documentTypeLabel(type),
      status: (map['status'] as String? ?? '').trim(),
      documentType: type,
    );
  }

  static String _documentTypeLabel(String type) => switch (type) {
    'estimate' => 'Devis',
    'invoice' => 'Facture',
    'repair_order' => 'Ordre de réparation',
    'technical_inspection_report' => 'Contrôle technique',
    'purchase_order' => 'Bon de commande',
    'sale_contract' => 'Contrat de vente',
    'lease_contract' => 'Contrat de location',
    'loa_contract' => 'Contrat LOA',
    'lld_contract' => 'Contrat LLD',
    'insurance_contract' => 'Contrat d’assurance',
    _ => 'Document automobile',
  };
}

class LegalOfficialSource {
  const LegalOfficialSource({
    required this.title,
    required this.url,
    required this.reference,
    required this.relevance,
  });

  final String title;
  final String url;
  final String reference;
  final String relevance;

  factory LegalOfficialSource.fromMap(Map<String, dynamic> map) =>
      LegalOfficialSource(
        title: map['title']?.toString() ?? 'Source officielle',
        url: map['url']?.toString() ?? '',
        reference: map['reference']?.toString() ?? '',
        relevance: map['relevance']?.toString() ?? '',
      );
}

class LegalAnalysisPoint {
  const LegalAnalysisPoint({required this.title, required this.explanation});

  final String title;
  final String explanation;

  factory LegalAnalysisPoint.fromMap(Map<String, dynamic> map) =>
      LegalAnalysisPoint(
        title: map['title']?.toString() ?? '',
        explanation: map['explanation']?.toString() ?? '',
      );
}

class LegalNextStep {
  const LegalNextStep({
    required this.order,
    required this.title,
    required this.description,
  });

  final int order;
  final String title;
  final String description;

  factory LegalNextStep.fromMap(Map<String, dynamic> map) => LegalNextStep(
    order: (map['order'] as num?)?.round() ?? 0,
    title: map['title']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
  );
}

class LegalFactualDraft {
  const LegalFactualDraft({
    required this.available,
    required this.title,
    required this.body,
  });

  final bool available;
  final String title;
  final String body;

  factory LegalFactualDraft.fromMap(Map<String, dynamic>? map) =>
      LegalFactualDraft(
        available: map?['available'] == true,
        title: map?['title']?.toString() ?? '',
        body: map?['body']?.toString() ?? '',
      );
}

class LegalAnalysisResult {
  const LegalAnalysisResult({
    required this.status,
    required this.caseSummary,
    required this.confirmedFacts,
    required this.documentPointsToVerify,
    required this.missingInformation,
    required this.officialSources,
    required this.analysisPoints,
    required this.nextSteps,
    required this.questionsToAnswer,
    required this.factualDraft,
    required this.disclaimer,
  });

  final String status;
  final String caseSummary;
  final List<String> confirmedFacts;
  final List<String> documentPointsToVerify;
  final List<String> missingInformation;
  final List<LegalOfficialSource> officialSources;
  final List<LegalAnalysisPoint> analysisPoints;
  final List<LegalNextStep> nextSteps;
  final List<String> questionsToAnswer;
  final LegalFactualDraft factualDraft;
  final String disclaimer;

  bool get escalationRequired => status == 'escalation_required';
  bool get dossierOnly => status == 'dossier_only';
  bool get needsInformation => status == 'needs_information';
  bool get sourceVerificationFailed => status == 'source_verification_failed';

  factory LegalAnalysisResult.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> maps(String key) =>
        (map[key] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);

    List<String> strings(String key) => (map[key] as List? ?? const <dynamic>[])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);

    return LegalAnalysisResult(
      status: map['status']?.toString() ?? 'needs_information',
      caseSummary: map['case_summary']?.toString() ?? '',
      confirmedFacts: strings('confirmed_facts'),
      documentPointsToVerify: strings('document_points_to_verify'),
      missingInformation: strings('missing_information'),
      officialSources: maps(
        'official_sources',
      ).map(LegalOfficialSource.fromMap).toList(growable: false),
      analysisPoints: maps(
        'analysis_points',
      ).map(LegalAnalysisPoint.fromMap).toList(growable: false),
      nextSteps:
          maps('next_steps').map(LegalNextStep.fromMap).toList(growable: false)
            ..sort((a, b) => a.order.compareTo(b.order)),
      questionsToAnswer: strings('questions_to_answer'),
      factualDraft: LegalFactualDraft.fromMap(
        map['factual_draft'] is Map
            ? Map<String, dynamic>.from(map['factual_draft'] as Map)
            : null,
      ),
      disclaimer: map['disclaimer']?.toString() ?? '',
    );
  }

  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('Dossier AutoClair - Litiges & démarches')
      ..writeln()
      ..writeln(caseSummary);

    if (confirmedFacts.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Faits confirmés :');
      for (final fact in confirmedFacts) {
        buffer.writeln('- $fact');
      }
    }
    if (missingInformation.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('À compléter :');
      for (final item in missingInformation) {
        buffer.writeln('- $item');
      }
    }
    if (nextSteps.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Prochaines démarches :');
      for (final step in nextSteps) {
        buffer.writeln('${step.order}. ${step.title} - ${step.description}');
      }
    }
    return buffer.toString().trim();
  }
}
