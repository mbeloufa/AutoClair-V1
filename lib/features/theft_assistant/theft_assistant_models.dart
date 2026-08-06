enum TheftIncidentType {
  vehicleTheft,
  attemptedTheft,
  breakIn,
  vandalism,
  plateTheft,
}

extension TheftIncidentTypeX on TheftIncidentType {
  String get databaseValue => switch (this) {
    TheftIncidentType.vehicleTheft => 'VEHICLE_THEFT',
    TheftIncidentType.attemptedTheft => 'ATTEMPTED_THEFT',
    TheftIncidentType.breakIn => 'BREAK_IN',
    TheftIncidentType.vandalism => 'VANDALISM',
    TheftIncidentType.plateTheft => 'PLATE_THEFT',
  };

  String get label => switch (this) {
    TheftIncidentType.vehicleTheft => 'Véhicule volé',
    TheftIncidentType.attemptedTheft => 'Tentative de vol',
    TheftIncidentType.breakIn => 'Effraction ou vol dans le véhicule',
    TheftIncidentType.vandalism => 'Vandalisme',
    TheftIncidentType.plateTheft => 'Plaque d’immatriculation volée',
  };

  String get timelineTitle => switch (this) {
    TheftIncidentType.vehicleTheft => 'Vol du véhicule',
    TheftIncidentType.attemptedTheft => 'Tentative de vol',
    TheftIncidentType.breakIn => 'Effraction du véhicule',
    TheftIncidentType.vandalism => 'Vandalisme sur le véhicule',
    TheftIncidentType.plateTheft => 'Vol de plaque d’immatriculation',
  };

  bool get usesTheftDeadline => this != TheftIncidentType.vandalism;
}

enum TheftContextType { home, publicRoad, parking, other }

extension TheftContextTypeX on TheftContextType {
  String get databaseValue => switch (this) {
    TheftContextType.home => 'HOME',
    TheftContextType.publicRoad => 'PUBLIC_ROAD',
    TheftContextType.parking => 'PARKING',
    TheftContextType.other => 'OTHER',
  };

  String get label => switch (this) {
    TheftContextType.home => 'Domicile ou garage',
    TheftContextType.publicRoad => 'Voie publique',
    TheftContextType.parking => 'Parking',
    TheftContextType.other => 'Autre contexte',
  };
}

enum TheftActionLevel {
  emergency,
  checkImpound,
  policeReport,
  insurerDeclaration,
  followUp,
}

extension TheftActionLevelX on TheftActionLevel {
  String get databaseValue => switch (this) {
    TheftActionLevel.emergency => 'EMERGENCY',
    TheftActionLevel.checkImpound => 'CHECK_IMPOUND',
    TheftActionLevel.policeReport => 'POLICE_REPORT',
    TheftActionLevel.insurerDeclaration => 'INSURER_DECLARATION',
    TheftActionLevel.followUp => 'FOLLOW_UP',
  };

  String get label => switch (this) {
    TheftActionLevel.emergency => 'Appeler immédiatement le 17',
    TheftActionLevel.checkImpound => 'Vérifier la mise en fourrière',
    TheftActionLevel.policeReport => 'Déposer plainte rapidement',
    TheftActionLevel.insurerDeclaration => 'Prévenir l’assureur',
    TheftActionLevel.followUp => 'Suivre le dossier',
  };
}

enum TheftCheckLevel { ready, warning, blocking, information }

extension TheftCheckLevelX on TheftCheckLevel {
  String get databaseValue => switch (this) {
    TheftCheckLevel.ready => 'READY',
    TheftCheckLevel.warning => 'WARNING',
    TheftCheckLevel.blocking => 'BLOCKING',
    TheftCheckLevel.information => 'INFORMATION',
  };

  String get label => switch (this) {
    TheftCheckLevel.ready => 'Fait',
    TheftCheckLevel.warning => 'À compléter',
    TheftCheckLevel.blocking => 'Prioritaire',
    TheftCheckLevel.information => 'Conseil',
  };
}

class TheftAssistantProfile {
  const TheftAssistantProfile({
    required this.vehicleId,
    required this.insurerName,
    required this.claimPhone,
    required this.assistancePhone,
    required this.contractReference,
    required this.trackerAvailable,
    required this.theftCoverageKnown,
  });

  final String vehicleId;
  final String insurerName;
  final String claimPhone;
  final String assistancePhone;
  final String contractReference;
  final bool trackerAvailable;
  final bool theftCoverageKnown;

  factory TheftAssistantProfile.defaults(String vehicleId) {
    return TheftAssistantProfile(
      vehicleId: vehicleId,
      insurerName: '',
      claimPhone: '',
      assistancePhone: '',
      contractReference: '',
      trackerAvailable: false,
      theftCoverageKnown: false,
    );
  }

  factory TheftAssistantProfile.fromMap(Map<String, dynamic> map) {
    return TheftAssistantProfile(
      vehicleId: map['vehicle_id']?.toString() ?? '',
      insurerName: map['insurer_name']?.toString() ?? '',
      claimPhone: map['claim_phone']?.toString() ?? '',
      assistancePhone: map['assistance_phone']?.toString() ?? '',
      contractReference: map['contract_reference']?.toString() ?? '',
      trackerAvailable: map['tracker_available'] as bool? ?? false,
      theftCoverageKnown: map['theft_coverage_known'] as bool? ?? false,
    );
  }

  void validate() {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    if (insurerName.trim().length > 100) {
      throw const FormatException(
        'Le nom de l’assureur est limité à 100 caractères.',
      );
    }
    if (contractReference.trim().length > 100) {
      throw const FormatException(
        'La référence du contrat est limitée à 100 caractères.',
      );
    }
    for (final phone in [claimPhone, assistancePhone]) {
      final normalized = normalizePhone(phone);
      if (phone.trim().isNotEmpty && normalized.length < 6) {
        throw const FormatException('Un numéro de téléphone est invalide.');
      }
    }
  }

  String? get callableClaimPhone {
    final normalized = normalizePhone(claimPhone);
    return normalized.length >= 6 ? normalized : null;
  }

  String? get callableAssistancePhone {
    final normalized = normalizePhone(assistancePhone);
    return normalized.length >= 6 ? normalized : null;
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'insurer_name': _nullIfEmpty(insurerName),
      'claim_phone': _nullIfEmpty(claimPhone),
      'assistance_phone': _nullIfEmpty(assistancePhone),
      'contract_reference': _nullIfEmpty(contractReference),
      'tracker_available': trackerAvailable,
      'theft_coverage_known': theftCoverageKnown,
    };
  }
}

class TheftCaseInput {
  const TheftCaseInput({
    required this.vehicleId,
    required this.occurredAt,
    required this.incidentType,
    required this.contextType,
    required this.incidentInProgress,
    required this.authorKnown,
    required this.vehicleMissing,
    required this.impoundChecked,
    required this.policeReported,
    required this.complaintReceiptAvailable,
    required this.insurerNotified,
    required this.registrationDocumentStolen,
    required this.insuranceDocumentsStolen,
    required this.drivingLicenceStolen,
    required this.keysAvailableCount,
    required this.photosTaken,
    required this.invoicesAvailable,
    required this.trackerDeclaredToPolice,
    required this.vehicleFound,
  });

  final String vehicleId;
  final DateTime occurredAt;
  final TheftIncidentType incidentType;
  final TheftContextType contextType;
  final bool incidentInProgress;
  final bool authorKnown;
  final bool vehicleMissing;
  final bool impoundChecked;
  final bool policeReported;
  final bool complaintReceiptAvailable;
  final bool insurerNotified;
  final bool registrationDocumentStolen;
  final bool insuranceDocumentsStolen;
  final bool drivingLicenceStolen;
  final int keysAvailableCount;
  final bool photosTaken;
  final bool invoicesAvailable;
  final bool trackerDeclaredToPolice;
  final bool vehicleFound;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    if (keysAvailableCount < 0 || keysAvailableCount > 4) {
      throw const FormatException(
        'Le nombre de clés disponibles est invalide.',
      );
    }
    final reference = now ?? DateTime.now();
    if (occurredAt.isAfter(reference.add(const Duration(minutes: 5)))) {
      throw const FormatException(
        'La date de découverte ne peut pas être dans le futur.',
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'occurred_at': _dateValue(occurredAt),
      'incident_type': incidentType.databaseValue,
      'context_type': contextType.databaseValue,
      'incident_in_progress': incidentInProgress,
      'author_known': authorKnown,
      'vehicle_missing': vehicleMissing,
      'impound_checked': impoundChecked,
      'police_reported': policeReported,
      'complaint_receipt_available': complaintReceiptAvailable,
      'insurer_notified': insurerNotified,
      'registration_document_stolen': registrationDocumentStolen,
      'insurance_documents_stolen': insuranceDocumentsStolen,
      'driving_licence_stolen': drivingLicenceStolen,
      'keys_available_count': keysAvailableCount,
      'photos_taken': photosTaken,
      'invoices_available': invoicesAvailable,
      'tracker_declared_to_police': trackerDeclaredToPolice,
      'vehicle_found': vehicleFound,
    };
  }
}

class TheftChecklistItem {
  const TheftChecklistItem({
    required this.code,
    required this.title,
    required this.detail,
    required this.level,
  });

  final String code;
  final String title;
  final String detail;
  final TheftCheckLevel level;

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'title': title,
      'detail': detail,
      'level': level.databaseValue,
    };
  }
}

class TheftAssessment {
  const TheftAssessment({
    required this.actionLevel,
    required this.score,
    required this.emergencyRequired,
    required this.onlineComplaintEligible,
    required this.declarationDueDate,
    required this.items,
    required this.evidenceSuggestions,
  });

  final TheftActionLevel actionLevel;
  final int score;
  final bool emergencyRequired;
  final bool onlineComplaintEligible;
  final DateTime declarationDueDate;
  final List<TheftChecklistItem> items;
  final List<String> evidenceSuggestions;

  int get blockingCount =>
      items.where((item) => item.level == TheftCheckLevel.blocking).length;

  int get warningCount =>
      items.where((item) => item.level == TheftCheckLevel.warning).length;

  String buildShareSummary({
    required TheftCaseInput input,
    required String vehicleLabel,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — DOSSIER VOL OU DÉGRADATION')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Date de découverte : ${_formatDate(input.occurredAt)}')
      ..writeln('Situation : ${input.incidentType.label}')
      ..writeln('Contexte général : ${input.contextType.label}')
      ..writeln('Orientation : ${actionLevel.label}')
      ..writeln('Véhicule manquant : ${input.vehicleMissing ? 'oui' : 'non'}')
      ..writeln('Fourrière vérifiée : ${input.impoundChecked ? 'oui' : 'non'}')
      ..writeln('Plainte déposée : ${input.policeReported ? 'oui' : 'non'}')
      ..writeln(
        'Récépissé disponible : '
        '${input.complaintReceiptAvailable ? 'oui' : 'non'}',
      )
      ..writeln('Assureur prévenu : ${input.insurerNotified ? 'oui' : 'non'}')
      ..writeln(
        'Échéance indicative : ${_formatDate(declarationDueDate)} '
        '(hors jours fériés, contrat prioritaire)',
      )
      ..writeln()
      ..writeln(
        'AutoClair organise les faits saisis. Il ne confirme ni la garantie, '
        'ni l’indemnisation, ni l’identité d’un auteur.',
      );
    return buffer.toString().trim();
  }
}

class TheftCaseSnapshot {
  const TheftCaseSnapshot({
    required this.id,
    required this.occurredAt,
    required this.incidentType,
    required this.actionLevel,
    required this.score,
    required this.insurerNotified,
  });

  final String id;
  final DateTime occurredAt;
  final TheftIncidentType incidentType;
  final TheftActionLevel actionLevel;
  final int score;
  final bool insurerNotified;

  factory TheftCaseSnapshot.fromMap(Map<String, dynamic> map) {
    return TheftCaseSnapshot(
      id: map['id']?.toString() ?? '',
      occurredAt: DateTime.parse(map['occurred_at'].toString()),
      incidentType: theftIncidentTypeFromDatabase(
        map['incident_type']?.toString(),
      ),
      actionLevel: theftActionLevelFromDatabase(
        map['action_level']?.toString(),
      ),
      score: (map['readiness_score'] as num?)?.toInt() ?? 0,
      insurerNotified: map['insurer_notified'] as bool? ?? false,
    );
  }
}

TheftIncidentType theftIncidentTypeFromDatabase(String? value) {
  return switch (value) {
    'ATTEMPTED_THEFT' => TheftIncidentType.attemptedTheft,
    'BREAK_IN' => TheftIncidentType.breakIn,
    'VANDALISM' => TheftIncidentType.vandalism,
    'PLATE_THEFT' => TheftIncidentType.plateTheft,
    _ => TheftIncidentType.vehicleTheft,
  };
}

TheftActionLevel theftActionLevelFromDatabase(String? value) {
  return switch (value) {
    'EMERGENCY' => TheftActionLevel.emergency,
    'CHECK_IMPOUND' => TheftActionLevel.checkImpound,
    'POLICE_REPORT' => TheftActionLevel.policeReport,
    'INSURER_DECLARATION' => TheftActionLevel.insurerDeclaration,
    _ => TheftActionLevel.followUp,
  };
}

String normalizePhone(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final character = String.fromCharCode(codeUnit);
    if (RegExp(r'[0-9]').hasMatch(character)) {
      buffer.write(character);
    } else if (character == '+' && buffer.isEmpty) {
      buffer.write(character);
    }
  }
  return buffer.toString();
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

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
