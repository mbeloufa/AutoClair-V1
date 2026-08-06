enum VehicleInspectionPurpose { routine, purchase, sale, returnLease }

extension VehicleInspectionPurposeX on VehicleInspectionPurpose {
  String get databaseValue => switch (this) {
    VehicleInspectionPurpose.routine => 'ROUTINE',
    VehicleInspectionPurpose.purchase => 'PURCHASE',
    VehicleInspectionPurpose.sale => 'SALE',
    VehicleInspectionPurpose.returnLease => 'RETURN_LEASE',
  };

  String get label => switch (this) {
    VehicleInspectionPurpose.routine => 'Contrôle périodique',
    VehicleInspectionPurpose.purchase => 'Avant un achat',
    VehicleInspectionPurpose.sale => 'Avant une vente',
    VehicleInspectionPurpose.returnLease => 'Avant une restitution',
  };
}

enum VehicleInspectionStatus { notChecked, good, monitor, repair, urgent }

extension VehicleInspectionStatusX on VehicleInspectionStatus {
  String get databaseValue => switch (this) {
    VehicleInspectionStatus.notChecked => 'NOT_CHECKED',
    VehicleInspectionStatus.good => 'GOOD',
    VehicleInspectionStatus.monitor => 'MONITOR',
    VehicleInspectionStatus.repair => 'REPAIR',
    VehicleInspectionStatus.urgent => 'URGENT',
  };

  String get label => switch (this) {
    VehicleInspectionStatus.notChecked => 'Non vérifié',
    VehicleInspectionStatus.good => 'Bon état apparent',
    VehicleInspectionStatus.monitor => 'À surveiller',
    VehicleInspectionStatus.repair => 'À corriger',
    VehicleInspectionStatus.urgent => 'Contrôle prioritaire',
  };
}

enum VehicleInspectionLevel { reassuring, monitor, action, priority }

extension VehicleInspectionLevelX on VehicleInspectionLevel {
  String get databaseValue => switch (this) {
    VehicleInspectionLevel.reassuring => 'REASSURING',
    VehicleInspectionLevel.monitor => 'MONITOR',
    VehicleInspectionLevel.action => 'ACTION',
    VehicleInspectionLevel.priority => 'PRIORITY',
  };

  String get label => switch (this) {
    VehicleInspectionLevel.reassuring => 'État apparent rassurant',
    VehicleInspectionLevel.monitor => 'Points à surveiller',
    VehicleInspectionLevel.action => 'Actions à prévoir',
    VehicleInspectionLevel.priority => 'Contrôle prioritaire',
  };
}

enum VehicleInspectionArea {
  bodywork,
  glassLighting,
  tires,
  brakes,
  fluids,
  dashboard,
  interior,
  equipment,
  documents,
  keys,
}

extension VehicleInspectionAreaX on VehicleInspectionArea {
  String get databaseValue => switch (this) {
    VehicleInspectionArea.bodywork => 'BODYWORK',
    VehicleInspectionArea.glassLighting => 'GLASS_LIGHTING',
    VehicleInspectionArea.tires => 'TIRES',
    VehicleInspectionArea.brakes => 'BRAKES',
    VehicleInspectionArea.fluids => 'FLUIDS',
    VehicleInspectionArea.dashboard => 'DASHBOARD',
    VehicleInspectionArea.interior => 'INTERIOR',
    VehicleInspectionArea.equipment => 'EQUIPMENT',
    VehicleInspectionArea.documents => 'DOCUMENTS',
    VehicleInspectionArea.keys => 'KEYS',
  };

  String get label => switch (this) {
    VehicleInspectionArea.bodywork => 'Carrosserie et ouvrants',
    VehicleInspectionArea.glassLighting => 'Vitrages et éclairage',
    VehicleInspectionArea.tires => 'Pneus',
    VehicleInspectionArea.brakes => 'Freinage apparent',
    VehicleInspectionArea.fluids => 'Niveaux et fuites visibles',
    VehicleInspectionArea.dashboard => 'Voyants et démarrage',
    VehicleInspectionArea.interior => 'Habitacle',
    VehicleInspectionArea.equipment => 'Équipements principaux',
    VehicleInspectionArea.documents => 'Documents du véhicule',
    VehicleInspectionArea.keys => 'Clés et accessoires remis',
  };

  String get action => switch (this) {
    VehicleInspectionArea.bodywork =>
      'Photographiez les défauts et demandez un chiffrage si nécessaire.',
    VehicleInspectionArea.glassLighting =>
      'Faites contrôler tout vitrage fissuré ou éclairage défaillant.',
    VehicleInspectionArea.tires =>
      'Contrôlez l’usure, la pression et l’absence de déformation.',
    VehicleInspectionArea.brakes =>
      'Faites vérifier le freinage par un professionnel avant de poursuivre.',
    VehicleInspectionArea.fluids =>
      'Identifiez l’origine d’une fuite ou d’un niveau anormal.',
    VehicleInspectionArea.dashboard =>
      'Faites lire les voyants persistants et évitez d’ignorer une alerte rouge.',
    VehicleInspectionArea.interior =>
      'Listez les réparations utiles avant la transaction ou la restitution.',
    VehicleInspectionArea.equipment =>
      'Testez les fonctions annoncées et conservez les éléments manquants.',
    VehicleInspectionArea.documents =>
      'Vérifiez la cohérence des documents avant tout paiement ou remise.',
    VehicleInspectionArea.keys =>
      'Confirmez le nombre de clés et le fonctionnement des télécommandes.',
  };

  bool get safetyCritical => switch (this) {
    VehicleInspectionArea.tires ||
    VehicleInspectionArea.brakes ||
    VehicleInspectionArea.fluids ||
    VehicleInspectionArea.dashboard => true,
    _ => false,
  };
}

class VehicleInspectionProfile {
  const VehicleInspectionProfile({
    required this.vehicleId,
    required this.purpose,
    required this.checks,
    required this.roadTestCompleted,
    required this.photosAvailable,
    required this.professionalCheckPlanned,
  });

  final String vehicleId;
  final VehicleInspectionPurpose purpose;
  final Map<VehicleInspectionArea, VehicleInspectionStatus> checks;
  final bool roadTestCompleted;
  final bool photosAvailable;
  final bool professionalCheckPlanned;

  factory VehicleInspectionProfile.defaults(String vehicleId) {
    return VehicleInspectionProfile(
      vehicleId: vehicleId,
      purpose: VehicleInspectionPurpose.routine,
      checks: {
        for (final area in VehicleInspectionArea.values)
          area: VehicleInspectionStatus.notChecked,
      },
      roadTestCompleted: false,
      photosAvailable: false,
      professionalCheckPlanned: false,
    );
  }

  VehicleInspectionStatus statusOf(VehicleInspectionArea area) {
    return checks[area] ?? VehicleInspectionStatus.notChecked;
  }

  void validate() {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    for (final area in VehicleInspectionArea.values) {
      if (!checks.containsKey(area)) {
        throw FormatException('Le point « ${area.label} » est absent.');
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'purpose': purpose.databaseValue,
      'checks': {
        for (final entry in checks.entries)
          entry.key.databaseValue: entry.value.databaseValue,
      },
      'road_test_completed': roadTestCompleted,
      'photos_available': photosAvailable,
      'professional_check_planned': professionalCheckPlanned,
    };
  }
}

class VehicleInspectionFinding {
  const VehicleInspectionFinding({
    required this.code,
    required this.area,
    required this.status,
    required this.title,
    required this.action,
  });

  final String code;
  final VehicleInspectionArea area;
  final VehicleInspectionStatus status;
  final String title;
  final String action;

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'area': area.databaseValue,
      'status': status.databaseValue,
      'title': title,
      'action': action,
    };
  }
}

class VehicleInspectionAssessment {
  const VehicleInspectionAssessment({
    required this.score,
    required this.level,
    required this.completenessPercent,
    required this.immediateAction,
    required this.checkedCount,
    required this.positiveCount,
    required this.findings,
  });

  final int score;
  final VehicleInspectionLevel level;
  final int completenessPercent;
  final bool immediateAction;
  final int checkedCount;
  final int positiveCount;
  final List<VehicleInspectionFinding> findings;

  String buildShareSummary({
    required String vehicleLabel,
    required VehicleInspectionPurpose purpose,
  }) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — INSPECTION VISUELLE GUIDÉE')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Contexte : ${purpose.label}')
      ..writeln('État apparent : ${level.label}')
      ..writeln('Indice indicatif : $score/100')
      ..writeln('Contrôle complété : $completenessPercent %')
      ..writeln(
        'Points vérifiés : $checkedCount/${VehicleInspectionArea.values.length}',
      )
      ..writeln();
    if (findings.isEmpty) {
      buffer.writeln('Aucun défaut déclaré parmi les points vérifiés.');
    } else {
      buffer.writeln('Points à traiter :');
      for (final finding in findings.take(6)) {
        buffer.writeln('- ${finding.title} : ${finding.action}');
      }
    }
    buffer
      ..writeln()
      ..writeln(
        'Cette synthèse repose sur vos observations. Elle ne remplace ni un contrôle technique, ni une expertise, ni un diagnostic professionnel.',
      );
    return buffer.toString().trim();
  }
}

class VehicleInspectionSnapshot {
  const VehicleInspectionSnapshot({
    required this.id,
    required this.purpose,
    required this.score,
    required this.level,
    required this.completenessPercent,
    required this.createdAt,
  });

  final String id;
  final VehicleInspectionPurpose purpose;
  final int score;
  final VehicleInspectionLevel level;
  final int completenessPercent;
  final DateTime createdAt;

  factory VehicleInspectionSnapshot.fromMap(Map<String, dynamic> map) {
    return VehicleInspectionSnapshot(
      id: map['id']?.toString() ?? '',
      purpose: vehicleInspectionPurposeFromDatabase(map['purpose']?.toString()),
      score: (map['condition_score'] as num?)?.toInt() ?? 0,
      level: vehicleInspectionLevelFromDatabase(
        map['condition_level']?.toString(),
      ),
      completenessPercent: (map['completeness_percent'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'].toString()),
    );
  }
}

VehicleInspectionPurpose vehicleInspectionPurposeFromDatabase(String? value) {
  return switch (value) {
    'PURCHASE' => VehicleInspectionPurpose.purchase,
    'SALE' => VehicleInspectionPurpose.sale,
    'RETURN_LEASE' => VehicleInspectionPurpose.returnLease,
    _ => VehicleInspectionPurpose.routine,
  };
}

VehicleInspectionLevel vehicleInspectionLevelFromDatabase(String? value) {
  return switch (value) {
    'MONITOR' => VehicleInspectionLevel.monitor,
    'ACTION' => VehicleInspectionLevel.action,
    'PRIORITY' => VehicleInspectionLevel.priority,
    _ => VehicleInspectionLevel.reassuring,
  };
}
