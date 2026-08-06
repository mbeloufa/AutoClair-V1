enum LeaseReturnContext {
  endOfContract,
  earlyReturn,
  beforePreInspection,
  compareReturnOrPurchase,
}

extension LeaseReturnContextX on LeaseReturnContext {
  String get databaseValue => switch (this) {
    LeaseReturnContext.endOfContract => 'END_OF_CONTRACT',
    LeaseReturnContext.earlyReturn => 'EARLY_RETURN',
    LeaseReturnContext.beforePreInspection => 'BEFORE_PRE_INSPECTION',
    LeaseReturnContext.compareReturnOrPurchase => 'COMPARE_RETURN_OR_PURCHASE',
  };

  String get label => switch (this) {
    LeaseReturnContext.endOfContract => 'Fin de LOA ou LLD',
    LeaseReturnContext.earlyReturn => 'Restitution anticipée',
    LeaseReturnContext.beforePreInspection => 'Avant une pré-inspection',
    LeaseReturnContext.compareReturnOrPurchase =>
      'Comparer restitution et option d’achat',
  };
}

enum LeaseReturnStatus {
  notChecked,
  notApplicable,
  ready,
  toComplete,
  professionalReview,
  priority,
}

extension LeaseReturnStatusX on LeaseReturnStatus {
  String get databaseValue => switch (this) {
    LeaseReturnStatus.notChecked => 'NOT_CHECKED',
    LeaseReturnStatus.notApplicable => 'NOT_APPLICABLE',
    LeaseReturnStatus.ready => 'READY',
    LeaseReturnStatus.toComplete => 'TO_COMPLETE',
    LeaseReturnStatus.professionalReview => 'PROFESSIONAL_REVIEW',
    LeaseReturnStatus.priority => 'PRIORITY',
  };

  String get label => switch (this) {
    LeaseReturnStatus.notChecked => 'Non vérifié',
    LeaseReturnStatus.notApplicable => 'Non applicable au contrat',
    LeaseReturnStatus.ready => 'Prêt',
    LeaseReturnStatus.toComplete => 'À compléter',
    LeaseReturnStatus.professionalReview => 'Contrôle à prévoir',
    LeaseReturnStatus.priority => 'Prioritaire avant restitution',
  };
}

enum LeaseReturnLevel { ready, review, action, urgent }

extension LeaseReturnLevelX on LeaseReturnLevel {
  String get databaseValue => switch (this) {
    LeaseReturnLevel.ready => 'READY',
    LeaseReturnLevel.review => 'REVIEW',
    LeaseReturnLevel.action => 'ACTION',
    LeaseReturnLevel.urgent => 'URGENT',
  };

  String get label => switch (this) {
    LeaseReturnLevel.ready => 'Préparation complétée',
    LeaseReturnLevel.review => 'Préparation à compléter',
    LeaseReturnLevel.action => 'Actions à prévoir',
    LeaseReturnLevel.urgent => 'Point prioritaire',
  };
}

enum LeaseReturnArea {
  contractAndInstructions,
  returnTiming,
  mileageAndUsage,
  keysAndAccessories,
  exteriorGlassAndWheels,
  interiorAndEquipment,
  maintenanceAndDocuments,
  warningLightsAndMechanical,
  cleaningAndPersonalData,
  preInspectionAndHandover,
}

extension LeaseReturnAreaX on LeaseReturnArea {
  String get databaseValue => switch (this) {
    LeaseReturnArea.contractAndInstructions => 'CONTRACT_AND_INSTRUCTIONS',
    LeaseReturnArea.returnTiming => 'RETURN_TIMING',
    LeaseReturnArea.mileageAndUsage => 'MILEAGE_AND_USAGE',
    LeaseReturnArea.keysAndAccessories => 'KEYS_AND_ACCESSORIES',
    LeaseReturnArea.exteriorGlassAndWheels => 'EXTERIOR_GLASS_AND_WHEELS',
    LeaseReturnArea.interiorAndEquipment => 'INTERIOR_AND_EQUIPMENT',
    LeaseReturnArea.maintenanceAndDocuments => 'MAINTENANCE_AND_DOCUMENTS',
    LeaseReturnArea.warningLightsAndMechanical =>
      'WARNING_LIGHTS_AND_MECHANICAL',
    LeaseReturnArea.cleaningAndPersonalData => 'CLEANING_AND_PERSONAL_DATA',
    LeaseReturnArea.preInspectionAndHandover => 'PRE_INSPECTION_AND_HANDOVER',
  };

  String get label => switch (this) {
    LeaseReturnArea.contractAndInstructions =>
      'Contrat et consignes de restitution',
    LeaseReturnArea.returnTiming => 'Échéance, rendez-vous et délai disponible',
    LeaseReturnArea.mileageAndUsage =>
      'Kilométrage et usage à rapprocher du contrat',
    LeaseReturnArea.keysAndAccessories =>
      'Clés, câbles, accessoires et notices',
    LeaseReturnArea.exteriorGlassAndWheels =>
      'Carrosserie, vitrages, roues et pneus visibles',
    LeaseReturnArea.interiorAndEquipment => 'Habitacle et équipements présents',
    LeaseReturnArea.maintenanceAndDocuments =>
      'Entretien et documents disponibles',
    LeaseReturnArea.warningLightsAndMechanical =>
      'Voyants ou anomalie mécanique déclarée',
    LeaseReturnArea.cleaningAndPersonalData =>
      'Nettoyage et suppression des données personnelles',
    LeaseReturnArea.preInspectionAndHandover =>
      'Pré-inspection, photos personnelles et remise',
  };

  bool get isPriorityArea =>
      this == LeaseReturnArea.contractAndInstructions ||
      this == LeaseReturnArea.keysAndAccessories ||
      this == LeaseReturnArea.maintenanceAndDocuments ||
      this == LeaseReturnArea.warningLightsAndMechanical ||
      this == LeaseReturnArea.preInspectionAndHandover;
}

class LeaseReturnProfile {
  const LeaseReturnProfile({
    required this.vehicleId,
    required this.preparedAt,
    required this.preparationContext,
    required this.checks,
    required this.vehicleCanMoveSafely,
    required this.contractInstructionsAvailable,
    required this.allKeysAndAccessoriesAvailable,
    required this.warningOrMechanicalConcern,
  });

  final String vehicleId;
  final DateTime preparedAt;
  final LeaseReturnContext preparationContext;
  final Map<LeaseReturnArea, LeaseReturnStatus> checks;
  final bool vehicleCanMoveSafely;
  final bool contractInstructionsAvailable;
  final bool allKeysAndAccessoriesAvailable;
  final bool warningOrMechanicalConcern;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in LeaseReturnArea.values) {
      if (!checks.containsKey(area)) {
        throw FormatException('Le point « ${area.label} » est absent.');
      }
    }
    final reference = (now ?? DateTime.now()).toLocal();
    final selected = DateTime(
      preparedAt.year,
      preparedAt.month,
      preparedAt.day,
    );
    final today = DateTime(reference.year, reference.month, reference.day);
    if (selected.isBefore(today.subtract(const Duration(days: 90)))) {
      throw const FormatException('La date de préparation est trop ancienne.');
    }
    if (selected.isAfter(today.add(const Duration(days: 1)))) {
      throw const FormatException('La date de préparation est dans le futur.');
    }
  }

  Map<String, dynamic> toMap() => {
    'vehicle_id': vehicleId,
    'prepared_at': _dateValue(preparedAt),
    'preparation_context': preparationContext.databaseValue,
    'vehicle_can_move_safely': vehicleCanMoveSafely,
    'contract_instructions_available': contractInstructionsAvailable,
    'all_keys_and_accessories_available': allKeysAndAccessoriesAvailable,
    'warning_or_mechanical_concern': warningOrMechanicalConcern,
    'checks': {
      for (final entry in checks.entries)
        entry.key.databaseValue: entry.value.databaseValue,
    },
  };
}

class LeaseReturnFinding {
  const LeaseReturnFinding({
    required this.code,
    required this.title,
    required this.action,
    required this.urgent,
  });

  final String code;
  final String title;
  final String action;
  final bool urgent;

  Map<String, dynamic> toMap() => {
    'code': code,
    'title': title,
    'action': action,
    'urgent': urgent,
  };
}

class LeaseReturnAssessment {
  const LeaseReturnAssessment({
    required this.level,
    required this.score,
    required this.completenessPercent,
    required this.urgentCount,
    required this.findings,
  });

  final LeaseReturnLevel level;
  final int score;
  final int completenessPercent;
  final int urgentCount;
  final List<LeaseReturnFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required LeaseReturnProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — PRÉPARATION RESTITUTION LOA / LLD')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Contexte : ${profile.preparationContext.label}')
      ..writeln('Date de préparation : ${_formatDate(profile.preparedAt)}')
      ..writeln('État : ${level.label}')
      ..writeln('Indice déclaratif : $score/100')
      ..writeln('Points préparés : $completenessPercent %')
      ..writeln('Points prioritaires déclarés : $urgentCount');
    if (findings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Actions principales :');
      for (final finding in findings.take(6)) {
        buffer.writeln('- ${finding.title} : ${finding.action}');
      }
    }
    buffer
      ..writeln()
      ..writeln(
        'Ce résumé est un outil de préparation déclaratif. Il ne calcule aucun '
        'frais de restitution, n’interprète pas le contrat et ne garantit pas '
        'l’acceptation du véhicule. Le contrat, les consignes du loueur et le '
        'procès-verbal de restitution restent les références.',
      );
    return buffer.toString().trim();
  }
}

class LeaseReturnSnapshot {
  const LeaseReturnSnapshot({
    required this.id,
    required this.preparedAt,
    required this.preparationContext,
    required this.level,
    required this.score,
    required this.completenessPercent,
  });

  final String id;
  final DateTime preparedAt;
  final LeaseReturnContext preparationContext;
  final LeaseReturnLevel level;
  final int score;
  final int completenessPercent;

  factory LeaseReturnSnapshot.fromMap(Map<String, dynamic> map) {
    return LeaseReturnSnapshot(
      id: map['id']?.toString() ?? '',
      preparedAt: DateTime.parse(map['prepared_at'].toString()),
      preparationContext: leaseReturnContextFromDatabase(
        map['preparation_context']?.toString(),
      ),
      level: leaseReturnLevelFromDatabase(map['preparation_level']?.toString()),
      score: (map['preparation_score'] as num?)?.toInt() ?? 0,
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

LeaseReturnContext leaseReturnContextFromDatabase(String? value) =>
    switch (value) {
      'EARLY_RETURN' => LeaseReturnContext.earlyReturn,
      'BEFORE_PRE_INSPECTION' => LeaseReturnContext.beforePreInspection,
      'COMPARE_RETURN_OR_PURCHASE' =>
        LeaseReturnContext.compareReturnOrPurchase,
      _ => LeaseReturnContext.endOfContract,
    };

LeaseReturnLevel leaseReturnLevelFromDatabase(String? value) => switch (value) {
  'REVIEW' => LeaseReturnLevel.review,
  'ACTION' => LeaseReturnLevel.action,
  'URGENT' => LeaseReturnLevel.urgent,
  _ => LeaseReturnLevel.ready,
};

String _dateValue(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
