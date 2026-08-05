enum EcoDrivingEnergyType { fuel, electric }

extension EcoDrivingEnergyTypeX on EcoDrivingEnergyType {
  String get databaseValue => switch (this) {
    EcoDrivingEnergyType.fuel => 'fuel',
    EcoDrivingEnergyType.electric => 'electric',
  };

  String get label => switch (this) {
    EcoDrivingEnergyType.fuel => 'Carburant',
    EcoDrivingEnergyType.electric => 'Électricité',
  };

  String get consumptionUnit => switch (this) {
    EcoDrivingEnergyType.fuel => 'L/100 km',
    EcoDrivingEnergyType.electric => 'kWh/100 km',
  };

  String get priceUnit => switch (this) {
    EcoDrivingEnergyType.fuel => '€/L',
    EcoDrivingEnergyType.electric => '€/kWh',
  };

  static EcoDrivingEnergyType fromDatabase(Object? value) {
    return value?.toString() == 'electric'
        ? EcoDrivingEnergyType.electric
        : EcoDrivingEnergyType.fuel;
  }

  static EcoDrivingEnergyType inferFromFuelType(String? fuelType) {
    final normalized = fuelType?.toLowerCase().trim() ?? '';
    if (normalized.contains('electric') ||
        normalized.contains('électri') ||
        normalized == 'ev') {
      return EcoDrivingEnergyType.electric;
    }
    return EcoDrivingEnergyType.fuel;
  }
}

class EcoDrivingProfile {
  const EcoDrivingProfile({
    required this.energyType,
    required this.consumptionPer100Km,
    required this.energyPrice,
    required this.potentialGainPercent,
  });

  final EcoDrivingEnergyType energyType;
  final double consumptionPer100Km;
  final double energyPrice;
  final double potentialGainPercent;

  factory EcoDrivingProfile.defaultsForFuelType(String? fuelType) {
    final energyType = EcoDrivingEnergyTypeX.inferFromFuelType(fuelType);
    return EcoDrivingProfile(
      energyType: energyType,
      consumptionPer100Km: energyType == EcoDrivingEnergyType.electric
          ? 18.0
          : 6.5,
      energyPrice: energyType == EcoDrivingEnergyType.electric ? 0.25 : 1.85,
      potentialGainPercent: 5.0,
    );
  }

  factory EcoDrivingProfile.fromMap(Map<String, dynamic> map) {
    return EcoDrivingProfile(
      energyType: EcoDrivingEnergyTypeX.fromDatabase(map['energy_type']),
      consumptionPer100Km: _decimal(map['consumption_per_100km']),
      energyPrice: _decimal(map['energy_price']),
      potentialGainPercent: _decimal(map['potential_gain_percent']),
    );
  }
}

class EcoDrivingSample {
  const EcoDrivingSample({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedMps,
    required this.accuracyMeters,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedMps;
  final double accuracyMeters;
}

class EcoDrivingLiveMetrics {
  const EcoDrivingLiveMetrics({
    required this.durationSeconds,
    required this.distanceKm,
    required this.currentSpeedKph,
    required this.harshAccelerationCount,
    required this.harshBrakingCount,
    required this.acceptedSampleCount,
    required this.discardedSampleCount,
  });

  const EcoDrivingLiveMetrics.empty()
    : durationSeconds = 0,
      distanceKm = 0,
      currentSpeedKph = 0,
      harshAccelerationCount = 0,
      harshBrakingCount = 0,
      acceptedSampleCount = 0,
      discardedSampleCount = 0;

  final int durationSeconds;
  final double distanceKm;
  final double currentSpeedKph;
  final int harshAccelerationCount;
  final int harshBrakingCount;
  final int acceptedSampleCount;
  final int discardedSampleCount;
}

class EcoDrivingSessionSummary {
  const EcoDrivingSessionSummary({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.movingSeconds,
    required this.idleSeconds,
    required this.distanceKm,
    required this.averageSpeedKph,
    required this.harshAccelerationCount,
    required this.harshBrakingCount,
    required this.acceptedSampleCount,
    required this.discardedSampleCount,
    required this.score,
    required this.baselineEnergyCost,
    required this.potentialSaving,
    required this.recommendations,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int movingSeconds;
  final int idleSeconds;
  final double distanceKm;
  final double averageSpeedKph;
  final int harshAccelerationCount;
  final int harshBrakingCount;
  final int acceptedSampleCount;
  final int discardedSampleCount;
  final int score;
  final double baselineEnergyCost;
  final double potentialSaving;
  final List<String> recommendations;

  bool get isMeaningful =>
      distanceKm >= 0.5 && durationSeconds >= 120 && acceptedSampleCount >= 5;

  double get idleRatio {
    final trackedSeconds = movingSeconds + idleSeconds;
    if (trackedSeconds <= 0) return 0;
    return idleSeconds / trackedSeconds;
  }
}

class EcoDrivingSessionRecord {
  const EcoDrivingSessionRecord({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.score,
    required this.potentialSaving,
  });

  final String id;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceKm;
  final int score;
  final double potentialSaving;

  factory EcoDrivingSessionRecord.fromMap(Map<String, dynamic> map) {
    return EcoDrivingSessionRecord(
      id: map['id'].toString(),
      startedAt: DateTime.parse(map['started_at'].toString()),
      durationSeconds: _integer(map['duration_seconds']),
      distanceKm: _decimal(map['distance_km']),
      score: _integer(map['score']),
      potentialSaving: _decimal(map['potential_saving']),
    );
  }
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
