enum AccidentLocationType { motorway, road, urban, parking }

extension AccidentLocationTypeX on AccidentLocationType {
  String get databaseValue => switch (this) {
    AccidentLocationType.motorway => 'MOTORWAY',
    AccidentLocationType.road => 'ROAD',
    AccidentLocationType.urban => 'URBAN',
    AccidentLocationType.parking => 'PARKING',
  };

  String get label => switch (this) {
    AccidentLocationType.motorway => 'Autoroute ou voie rapide',
    AccidentLocationType.road => 'Route hors agglomération',
    AccidentLocationType.urban => 'Agglomération',
    AccidentLocationType.parking => 'Stationnement ou parking',
  };
}

enum AccidentActionLevel {
  emergency,
  paperReport,
  electronicReport,
  insurerDeclaration,
}

extension AccidentActionLevelX on AccidentActionLevel {
  String get databaseValue => switch (this) {
    AccidentActionLevel.emergency => 'EMERGENCY',
    AccidentActionLevel.paperReport => 'PAPER_REPORT',
    AccidentActionLevel.electronicReport => 'ELECTRONIC_REPORT',
    AccidentActionLevel.insurerDeclaration => 'INSURER_DECLARATION',
  };

  String get label => switch (this) {
    AccidentActionLevel.emergency => 'Urgence et secours',
    AccidentActionLevel.paperReport => 'Constat papier requis',
    AccidentActionLevel.electronicReport => 'E-constat possible',
    AccidentActionLevel.insurerDeclaration => 'Déclaration à l’assureur',
  };
}

enum AccidentCheckLevel { ready, warning, blocking, information }

extension AccidentCheckLevelX on AccidentCheckLevel {
  String get databaseValue => switch (this) {
    AccidentCheckLevel.ready => 'READY',
    AccidentCheckLevel.warning => 'WARNING',
    AccidentCheckLevel.blocking => 'BLOCKING',
    AccidentCheckLevel.information => 'INFORMATION',
  };

  String get label => switch (this) {
    AccidentCheckLevel.ready => 'Fait',
    AccidentCheckLevel.warning => 'À compléter',
    AccidentCheckLevel.blocking => 'Prioritaire',
    AccidentCheckLevel.information => 'Conseil',
  };
}

class AccidentAssistantProfile {
  const AccidentAssistantProfile({
    required this.vehicleId,
    required this.insurerName,
    required this.claimPhone,
    required this.assistancePhone,
    required this.contractReference,
    required this.memoVehicleInsuredAvailable,
  });

  final String vehicleId;
  final String insurerName;
  final String claimPhone;
  final String assistancePhone;
  final String contractReference;
  final bool memoVehicleInsuredAvailable;

  factory AccidentAssistantProfile.defaults(String vehicleId) {
    return AccidentAssistantProfile(
      vehicleId: vehicleId,
      insurerName: '',
      claimPhone: '',
      assistancePhone: '',
      contractReference: '',
      memoVehicleInsuredAvailable: false,
    );
  }

  factory AccidentAssistantProfile.fromMap(Map<String, dynamic> map) {
    return AccidentAssistantProfile(
      vehicleId: map['vehicle_id']?.toString() ?? '',
      insurerName: map['insurer_name']?.toString() ?? '',
      claimPhone: map['claim_phone']?.toString() ?? '',
      assistancePhone: map['assistance_phone']?.toString() ?? '',
      contractReference: map['contract_reference']?.toString() ?? '',
      memoVehicleInsuredAvailable:
          map['memo_vehicle_insured_available'] as bool? ?? false,
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
      'memo_vehicle_insured_available': memoVehicleInsuredAvailable,
    };
  }
}

class AccidentCaseInput {
  const AccidentCaseInput({
    required this.vehicleId,
    required this.occurredAt,
    required this.locationType,
    required this.injured,
    required this.immediateDanger,
    required this.vehicleCount,
    required this.foreignVehicle,
    required this.materialDamageOnly,
    required this.otherPartyRefused,
    required this.emergencyCalled,
    required this.policeAttended,
    required this.witnessesPresent,
    required this.photosTaken,
    required this.sketchPrepared,
    required this.reportSigned,
    required this.insurerNotified,
    required this.memoAvailable,
  });

  final String vehicleId;
  final DateTime occurredAt;
  final AccidentLocationType locationType;
  final bool injured;
  final bool immediateDanger;
  final int vehicleCount;
  final bool foreignVehicle;
  final bool materialDamageOnly;
  final bool otherPartyRefused;
  final bool emergencyCalled;
  final bool policeAttended;
  final bool witnessesPresent;
  final bool photosTaken;
  final bool sketchPrepared;
  final bool reportSigned;
  final bool insurerNotified;
  final bool memoAvailable;

  void validate({DateTime? now}) {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    if (vehicleCount < 1 || vehicleCount > 10) {
      throw const FormatException('Le nombre de véhicules est invalide.');
    }
    final reference = now ?? DateTime.now();
    if (occurredAt.isAfter(reference.add(const Duration(minutes: 5)))) {
      throw const FormatException(
        'La date de l’accident ne peut pas être dans le futur.',
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'occurred_at': _dateValue(occurredAt),
      'location_type': locationType.databaseValue,
      'injured': injured,
      'immediate_danger': immediateDanger,
      'vehicle_count': vehicleCount,
      'foreign_vehicle': foreignVehicle,
      'material_damage_only': materialDamageOnly,
      'other_party_refused': otherPartyRefused,
      'emergency_called': emergencyCalled,
      'police_attended': policeAttended,
      'witnesses_present': witnessesPresent,
      'photos_taken': photosTaken,
      'sketch_prepared': sketchPrepared,
      'report_signed': reportSigned,
      'insurer_notified': insurerNotified,
      'memo_available': memoAvailable,
    };
  }
}

class AccidentChecklistItem {
  const AccidentChecklistItem({
    required this.code,
    required this.title,
    required this.detail,
    required this.level,
  });

  final String code;
  final String title;
  final String detail;
  final AccidentCheckLevel level;

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'title': title,
      'detail': detail,
      'level': level.databaseValue,
    };
  }
}

class AccidentAssessment {
  const AccidentAssessment({
    required this.actionLevel,
    required this.score,
    required this.emergencyRequired,
    required this.eConstatEligible,
    required this.paperReportRequired,
    required this.declarationDueDate,
    required this.items,
    required this.photoSuggestions,
  });

  final AccidentActionLevel actionLevel;
  final int score;
  final bool emergencyRequired;
  final bool eConstatEligible;
  final bool paperReportRequired;
  final DateTime declarationDueDate;
  final List<AccidentChecklistItem> items;
  final List<String> photoSuggestions;

  int get blockingCount =>
      items.where((item) => item.level == AccidentCheckLevel.blocking).length;

  int get warningCount =>
      items.where((item) => item.level == AccidentCheckLevel.warning).length;

  String buildShareSummary({
    required AccidentCaseInput input,
    required String vehicleLabel,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — DOSSIER ACCIDENT')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Date : ${_formatDate(input.occurredAt)}')
      ..writeln('Contexte : ${input.locationType.label}')
      ..writeln('Nombre de véhicules : ${input.vehicleCount}')
      ..writeln('Orientation : ${actionLevel.label}')
      ..writeln('Blessé déclaré : ${input.injured ? 'oui' : 'non'}')
      ..writeln(
        'Dommages uniquement matériels : '
        '${input.materialDamageOnly ? 'oui' : 'non'}',
      )
      ..writeln('Photos réalisées : ${input.photosTaken ? 'oui' : 'non'}')
      ..writeln('Croquis préparé : ${input.sketchPrepared ? 'oui' : 'non'}')
      ..writeln('Constat signé : ${input.reportSigned ? 'oui' : 'non'}')
      ..writeln('Assureur prévenu : ${input.insurerNotified ? 'oui' : 'non'}')
      ..writeln(
        'Échéance indicative de déclaration : '
        '${_formatDate(declarationDueDate)} (hors jours fériés)',
      )
      ..writeln()
      ..writeln(
        'AutoClair décrit les faits saisis et ne détermine jamais les responsabilités.',
      );
    return buffer.toString().trim();
  }
}

class AccidentCaseSnapshot {
  const AccidentCaseSnapshot({
    required this.id,
    required this.occurredAt,
    required this.actionLevel,
    required this.score,
    required this.insurerNotified,
  });

  final String id;
  final DateTime occurredAt;
  final AccidentActionLevel actionLevel;
  final int score;
  final bool insurerNotified;

  factory AccidentCaseSnapshot.fromMap(Map<String, dynamic> map) {
    return AccidentCaseSnapshot(
      id: map['id']?.toString() ?? '',
      occurredAt:
          DateTime.tryParse(map['occurred_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      actionLevel: _actionLevel(map['action_level']),
      score: _integer(map['readiness_score']),
      insurerNotified: map['insurer_notified'] as bool? ?? false,
    );
  }
}

String normalizePhone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final buffer = StringBuffer();
  for (var index = 0; index < trimmed.length; index++) {
    final character = trimmed[index];
    if (character == '+' && buffer.isEmpty) {
      buffer.write(character);
    } else if (RegExp(r'[0-9]').hasMatch(character)) {
      buffer.write(character);
    }
  }
  return buffer.toString();
}

AccidentActionLevel _actionLevel(dynamic value) {
  return switch (value?.toString()) {
    'EMERGENCY' => AccidentActionLevel.emergency,
    'PAPER_REPORT' => AccidentActionLevel.paperReport,
    'ELECTRONIC_REPORT' => AccidentActionLevel.electronicReport,
    _ => AccidentActionLevel.insurerDeclaration,
  };
}

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
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
