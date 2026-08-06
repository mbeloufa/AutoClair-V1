enum RiskForecastLevel { low, watch, elevated, priority }

extension RiskForecastLevelX on RiskForecastLevel {
  String get databaseValue => switch (this) {
    RiskForecastLevel.low => 'LOW',
    RiskForecastLevel.watch => 'WATCH',
    RiskForecastLevel.elevated => 'ELEVATED',
    RiskForecastLevel.priority => 'PRIORITY',
  };

  String get label => switch (this) {
    RiskForecastLevel.low => 'Risque limité',
    RiskForecastLevel.watch => 'À surveiller',
    RiskForecastLevel.elevated => 'Risque élevé',
    RiskForecastLevel.priority => 'Contrôle prioritaire',
  };

  String get guidance => switch (this) {
    RiskForecastLevel.low =>
      'Aucun signal majeur n’est identifié avec les informations fournies.',
    RiskForecastLevel.watch =>
      'Quelques facteurs méritent une vérification ou une planification.',
    RiskForecastLevel.elevated =>
      'Plusieurs facteurs justifient un contrôle professionnel prochain.',
    RiskForecastLevel.priority =>
      'Un signal de sécurité ou plusieurs facteurs importants nécessitent une action rapide.',
  };
}

enum RiskForecastConfidence { limited, medium, strong }

extension RiskForecastConfidenceX on RiskForecastConfidence {
  String get databaseValue => switch (this) {
    RiskForecastConfidence.limited => 'LIMITED',
    RiskForecastConfidence.medium => 'MEDIUM',
    RiskForecastConfidence.strong => 'STRONG',
  };

  String get label => switch (this) {
    RiskForecastConfidence.limited => 'Confiance limitée',
    RiskForecastConfidence.medium => 'Confiance moyenne',
    RiskForecastConfidence.strong => 'Confiance renforcée',
  };
}

enum RiskForecastHorizon { immediate, thirtyDays, ninetyDays, twelveMonths }

extension RiskForecastHorizonX on RiskForecastHorizon {
  String get databaseValue => switch (this) {
    RiskForecastHorizon.immediate => 'IMMEDIATE',
    RiskForecastHorizon.thirtyDays => 'THIRTY_DAYS',
    RiskForecastHorizon.ninetyDays => 'NINETY_DAYS',
    RiskForecastHorizon.twelveMonths => 'TWELVE_MONTHS',
  };

  String get label => switch (this) {
    RiskForecastHorizon.immediate => 'Dès maintenant',
    RiskForecastHorizon.thirtyDays => 'Sous 30 jours',
    RiskForecastHorizon.ninetyDays => 'Sous 90 jours',
    RiskForecastHorizon.twelveMonths => 'Dans les 12 mois',
  };
}

enum RiskForecastCategory {
  safety,
  maintenance,
  battery,
  engineCooling,
  wear,
  usage,
}

extension RiskForecastCategoryX on RiskForecastCategory {
  String get databaseValue => switch (this) {
    RiskForecastCategory.safety => 'SAFETY',
    RiskForecastCategory.maintenance => 'MAINTENANCE',
    RiskForecastCategory.battery => 'BATTERY',
    RiskForecastCategory.engineCooling => 'ENGINE_COOLING',
    RiskForecastCategory.wear => 'WEAR',
    RiskForecastCategory.usage => 'USAGE',
  };

  String get label => switch (this) {
    RiskForecastCategory.safety => 'Sécurité',
    RiskForecastCategory.maintenance => 'Entretien',
    RiskForecastCategory.battery => 'Batterie et démarrage',
    RiskForecastCategory.engineCooling => 'Moteur et refroidissement',
    RiskForecastCategory.wear => 'Usure',
    RiskForecastCategory.usage => 'Usage',
  };
}

class RiskForecastProfile {
  const RiskForecastProfile({
    required this.vehicleId,
    required this.currentMileage,
    required this.annualMileage,
    required this.vehicleAgeYears,
    required this.monthsSinceService,
    required this.kmSinceService,
    required this.shortTripsOften,
    required this.intensiveUse,
    required this.longImmobilization,
    required this.maintenancePlanned,
    required this.dashboardWarning,
    required this.brakingConcern,
    required this.tireConcern,
    required this.startingConcern,
    required this.engineCoolingConcern,
    required this.repeatedBreakdowns12m,
  });

  final String vehicleId;
  final int currentMileage;
  final int annualMileage;
  final int vehicleAgeYears;
  final int monthsSinceService;
  final int kmSinceService;
  final bool shortTripsOften;
  final bool intensiveUse;
  final bool longImmobilization;
  final bool maintenancePlanned;
  final bool dashboardWarning;
  final bool brakingConcern;
  final bool tireConcern;
  final bool startingConcern;
  final bool engineCoolingConcern;
  final int repeatedBreakdowns12m;

  factory RiskForecastProfile.defaults(String vehicleId) {
    return RiskForecastProfile(
      vehicleId: vehicleId,
      currentMileage: 0,
      annualMileage: 12000,
      vehicleAgeYears: 5,
      monthsSinceService: 12,
      kmSinceService: 10000,
      shortTripsOften: false,
      intensiveUse: false,
      longImmobilization: false,
      maintenancePlanned: false,
      dashboardWarning: false,
      brakingConcern: false,
      tireConcern: false,
      startingConcern: false,
      engineCoolingConcern: false,
      repeatedBreakdowns12m: 0,
    );
  }

  factory RiskForecastProfile.fromMap(Map<String, dynamic> map) {
    return RiskForecastProfile(
      vehicleId: map['vehicle_id']?.toString() ?? '',
      currentMileage: _intValue(map['current_mileage']),
      annualMileage: _intValue(map['annual_mileage'], fallback: 12000),
      vehicleAgeYears: _intValue(map['vehicle_age_years'], fallback: 5),
      monthsSinceService: _intValue(map['months_since_service'], fallback: 12),
      kmSinceService: _intValue(map['km_since_service'], fallback: 10000),
      shortTripsOften: map['short_trips_often'] as bool? ?? false,
      intensiveUse: map['intensive_use'] as bool? ?? false,
      longImmobilization: map['long_immobilization'] as bool? ?? false,
      maintenancePlanned: map['maintenance_planned'] as bool? ?? false,
      dashboardWarning: map['dashboard_warning'] as bool? ?? false,
      brakingConcern: map['braking_concern'] as bool? ?? false,
      tireConcern: map['tire_concern'] as bool? ?? false,
      startingConcern: map['starting_concern'] as bool? ?? false,
      engineCoolingConcern: map['engine_cooling_concern'] as bool? ?? false,
      repeatedBreakdowns12m: _intValue(map['repeated_breakdowns_12m']),
    );
  }

  void validate() {
    if (vehicleId.trim().isEmpty) {
      throw const FormatException('Sélectionnez un véhicule.');
    }
    if (currentMileage < 0 || currentMileage > 2000000) {
      throw const FormatException('Le kilométrage actuel est invalide.');
    }
    if (annualMileage < 0 || annualMileage > 200000) {
      throw const FormatException('Le kilométrage annuel est invalide.');
    }
    if (vehicleAgeYears < 0 || vehicleAgeYears > 80) {
      throw const FormatException('L’âge du véhicule est invalide.');
    }
    if (monthsSinceService < 0 || monthsSinceService > 240) {
      throw const FormatException('Le délai depuis l’entretien est invalide.');
    }
    if (kmSinceService < 0 || kmSinceService > 500000) {
      throw const FormatException(
        'La distance depuis l’entretien est invalide.',
      );
    }
    if (repeatedBreakdowns12m < 0 || repeatedBreakdowns12m > 20) {
      throw const FormatException('Le nombre de pannes récentes est invalide.');
    }
  }

  int get completedSignalCount {
    var count = 6;
    if (currentMileage > 0) count++;
    if (annualMileage > 0) count++;
    if (monthsSinceService > 0 || kmSinceService > 0) count++;
    if (dashboardWarning || brakingConcern || tireConcern) count++;
    if (startingConcern || engineCoolingConcern) count++;
    if (shortTripsOften || intensiveUse || longImmobilization) count++;
    return count;
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'current_mileage': currentMileage,
      'annual_mileage': annualMileage,
      'vehicle_age_years': vehicleAgeYears,
      'months_since_service': monthsSinceService,
      'km_since_service': kmSinceService,
      'short_trips_often': shortTripsOften,
      'intensive_use': intensiveUse,
      'long_immobilization': longImmobilization,
      'maintenance_planned': maintenancePlanned,
      'dashboard_warning': dashboardWarning,
      'braking_concern': brakingConcern,
      'tire_concern': tireConcern,
      'starting_concern': startingConcern,
      'engine_cooling_concern': engineCoolingConcern,
      'repeated_breakdowns_12m': repeatedBreakdowns12m,
    };
  }
}

class RiskForecastFactor {
  const RiskForecastFactor({
    required this.code,
    required this.category,
    required this.title,
    required this.detail,
    required this.action,
    required this.points,
    required this.horizon,
    required this.confidence,
    required this.safetyCritical,
  });

  final String code;
  final RiskForecastCategory category;
  final String title;
  final String detail;
  final String action;
  final int points;
  final RiskForecastHorizon horizon;
  final RiskForecastConfidence confidence;
  final bool safetyCritical;

  factory RiskForecastFactor.fromMap(Map<String, dynamic> map) {
    return RiskForecastFactor(
      code: map['code']?.toString() ?? '',
      category: riskForecastCategoryFromDatabase(map['category']?.toString()),
      title: map['title']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      points: _intValue(map['points']),
      horizon: riskForecastHorizonFromDatabase(map['horizon']?.toString()),
      confidence: riskForecastConfidenceFromDatabase(
        map['confidence']?.toString(),
      ),
      safetyCritical: map['safety_critical'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'category': category.databaseValue,
      'title': title,
      'detail': detail,
      'action': action,
      'points': points,
      'horizon': horizon.databaseValue,
      'confidence': confidence.databaseValue,
      'safety_critical': safetyCritical,
    };
  }
}

class RiskForecastAssessment {
  const RiskForecastAssessment({
    required this.score,
    required this.level,
    required this.dataConfidence,
    required this.factors,
    required this.generatedAt,
  });

  final int score;
  final RiskForecastLevel level;
  final RiskForecastConfidence dataConfidence;
  final List<RiskForecastFactor> factors;
  final DateTime generatedAt;

  List<RiskForecastFactor> get priorities {
    final sorted = [...factors]
      ..sort((a, b) {
        if (a.safetyCritical != b.safetyCritical) {
          return a.safetyCritical ? -1 : 1;
        }
        return b.points.compareTo(a.points);
      });
    return sorted.take(3).toList(growable: false);
  }

  bool get hasSafetyCritical => factors.any((factor) => factor.safetyCritical);

  String buildShareSummary({required String vehicleLabel}) {
    final buffer = StringBuffer()
      ..writeln('AUTOCLAIR — ANALYSE PRÉVENTIVE DES RISQUES')
      ..writeln('Véhicule : $vehicleLabel')
      ..writeln('Niveau : ${level.label}')
      ..writeln('Indice préventif : $score/100')
      ..writeln('Qualité des informations : ${dataConfidence.label}')
      ..writeln()
      ..writeln('Priorités :');
    for (final factor in priorities) {
      buffer.writeln('- ${factor.title} — ${factor.action}');
    }
    buffer
      ..writeln()
      ..writeln(
        'Cette estimation organise les informations déclarées. Elle ne constitue '
        'ni un diagnostic mécanique, ni une garantie de panne ou d’absence de panne.',
      );
    return buffer.toString().trim();
  }
}

class RiskForecastSnapshot {
  const RiskForecastSnapshot({
    required this.id,
    required this.score,
    required this.level,
    required this.dataConfidence,
    required this.createdAt,
  });

  final String id;
  final int score;
  final RiskForecastLevel level;
  final RiskForecastConfidence dataConfidence;
  final DateTime createdAt;

  factory RiskForecastSnapshot.fromMap(Map<String, dynamic> map) {
    return RiskForecastSnapshot(
      id: map['id']?.toString() ?? '',
      score: _intValue(map['risk_score']),
      level: riskForecastLevelFromDatabase(map['risk_level']?.toString()),
      dataConfidence: riskForecastConfidenceFromDatabase(
        map['data_confidence']?.toString(),
      ),
      createdAt: DateTime.parse(map['created_at'].toString()),
    );
  }
}

RiskForecastLevel riskForecastLevelFromDatabase(String? value) {
  return switch (value) {
    'WATCH' => RiskForecastLevel.watch,
    'ELEVATED' => RiskForecastLevel.elevated,
    'PRIORITY' => RiskForecastLevel.priority,
    _ => RiskForecastLevel.low,
  };
}

RiskForecastConfidence riskForecastConfidenceFromDatabase(String? value) {
  return switch (value) {
    'MEDIUM' => RiskForecastConfidence.medium,
    'STRONG' => RiskForecastConfidence.strong,
    _ => RiskForecastConfidence.limited,
  };
}

RiskForecastHorizon riskForecastHorizonFromDatabase(String? value) {
  return switch (value) {
    'IMMEDIATE' => RiskForecastHorizon.immediate,
    'THIRTY_DAYS' => RiskForecastHorizon.thirtyDays,
    'TWELVE_MONTHS' => RiskForecastHorizon.twelveMonths,
    _ => RiskForecastHorizon.ninetyDays,
  };
}

RiskForecastCategory riskForecastCategoryFromDatabase(String? value) {
  return switch (value) {
    'SAFETY' => RiskForecastCategory.safety,
    'BATTERY' => RiskForecastCategory.battery,
    'ENGINE_COOLING' => RiskForecastCategory.engineCooling,
    'WEAR' => RiskForecastCategory.wear,
    'USAGE' => RiskForecastCategory.usage,
    _ => RiskForecastCategory.maintenance,
  };
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
