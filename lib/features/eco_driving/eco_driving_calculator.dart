import 'dart:math' as math;

import 'eco_driving_models.dart';

class EcoDrivingTripAnalyzer {
  EcoDrivingTripAnalyzer({DateTime? startedAt})
    : _startedAt = startedAt ?? DateTime.now();

  static const double maximumAcceptedAccuracyMeters = 50;
  static const double maximumAcceptedSpeedMps = 60;
  static const double movingThresholdMps = 0.8;
  static const double harshAccelerationThresholdMps2 = 2.5;
  static const double harshBrakingThresholdMps2 = -3;
  static const int maximumSegmentSeconds = 30;

  final DateTime _startedAt;

  EcoDrivingSample? _lastSample;
  double _distanceMeters = 0;
  double _movingSeconds = 0;
  double _idleSeconds = 0;
  int _harshAccelerationCount = 0;
  int _harshBrakingCount = 0;
  int _acceptedSampleCount = 0;
  int _discardedSampleCount = 0;
  double _currentSpeedMps = 0;

  EcoDrivingLiveMetrics addSample(EcoDrivingSample sample) {
    if (!_isValidSample(sample)) {
      _discardedSampleCount++;
      return liveMetrics(sample.timestamp);
    }

    final previous = _lastSample;
    if (previous == null) {
      _lastSample = sample;
      _acceptedSampleCount = 1;
      _currentSpeedMps = _normalizedSpeed(sample.speedMps, fallback: 0);
      return liveMetrics(sample.timestamp);
    }

    final elapsedSeconds =
        sample.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    if (elapsedSeconds <= 0) {
      _discardedSampleCount++;
      return liveMetrics(sample.timestamp);
    }

    if (elapsedSeconds > maximumSegmentSeconds) {
      _discardedSampleCount++;
      _lastSample = sample;
      _acceptedSampleCount++;
      _currentSpeedMps = _normalizedSpeed(sample.speedMps, fallback: 0);
      return liveMetrics(sample.timestamp);
    }

    final segmentDistance = distanceBetweenMeters(
      previous.latitude,
      previous.longitude,
      sample.latitude,
      sample.longitude,
    );
    final inferredSpeed = segmentDistance / elapsedSeconds;
    if (!segmentDistance.isFinite || inferredSpeed > maximumAcceptedSpeedMps) {
      _discardedSampleCount++;
      _lastSample = sample;
      return liveMetrics(sample.timestamp);
    }

    final previousSpeed = _normalizedSpeed(
      previous.speedMps,
      fallback: inferredSpeed,
    );
    final currentSpeed = _normalizedSpeed(
      sample.speedMps,
      fallback: inferredSpeed,
    );
    final acceleration = (currentSpeed - previousSpeed) / elapsedSeconds;

    if (acceleration >= harshAccelerationThresholdMps2) {
      _harshAccelerationCount++;
    }
    if (acceleration <= harshBrakingThresholdMps2) {
      _harshBrakingCount++;
    }

    final averageSpeed = (previousSpeed + currentSpeed) / 2;
    if (averageSpeed >= movingThresholdMps) {
      _movingSeconds += elapsedSeconds;
      _distanceMeters += segmentDistance;
    } else {
      _idleSeconds += elapsedSeconds;
    }

    _acceptedSampleCount++;
    _lastSample = sample;
    _currentSpeedMps = currentSpeed;
    return liveMetrics(sample.timestamp);
  }

  EcoDrivingLiveMetrics liveMetrics([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(_startedAt).inSeconds;
    return EcoDrivingLiveMetrics(
      durationSeconds: elapsed < 0 ? 0 : elapsed,
      distanceKm: _distanceMeters / 1000,
      currentSpeedKph: _currentSpeedMps * 3.6,
      harshAccelerationCount: _harshAccelerationCount,
      harshBrakingCount: _harshBrakingCount,
      acceptedSampleCount: _acceptedSampleCount,
      discardedSampleCount: _discardedSampleCount,
    );
  }

  EcoDrivingSessionSummary finish({
    required EcoDrivingProfile profile,
    DateTime? endedAt,
  }) {
    _validateProfile(profile);
    final end = endedAt ?? DateTime.now();
    final durationSeconds = math
        .max(0, end.difference(_startedAt).inSeconds)
        .toInt();
    final distanceKm = _distanceMeters / 1000;
    final trackedSeconds = _movingSeconds + _idleSeconds;
    final idleRatio = trackedSeconds <= 0 ? 0.0 : _idleSeconds / trackedSeconds;
    final harshPenalty = math.min(
      45,
      _harshAccelerationCount * 5 + _harshBrakingCount * 6,
    );
    final idlePenalty = math.min(20, (idleRatio * 25).round());
    final score = (100 - harshPenalty - idlePenalty).clamp(0, 100).toInt();
    final energyUsed = distanceKm / 100 * profile.consumptionPer100Km;
    final baselineEnergyCost = energyUsed * profile.energyPrice;
    final opportunityFactor = ((100 - score) / 50).clamp(0, 1).toDouble();
    final potentialSaving =
        baselineEnergyCost *
        (profile.potentialGainPercent / 100) *
        opportunityFactor;
    final averageSpeedKph = _movingSeconds <= 0
        ? 0.0
        : distanceKm / (_movingSeconds / 3600);

    return EcoDrivingSessionSummary(
      startedAt: _startedAt,
      endedAt: end,
      durationSeconds: durationSeconds,
      movingSeconds: _movingSeconds.round(),
      idleSeconds: _idleSeconds.round(),
      distanceKm: distanceKm,
      averageSpeedKph: averageSpeedKph,
      harshAccelerationCount: _harshAccelerationCount,
      harshBrakingCount: _harshBrakingCount,
      acceptedSampleCount: _acceptedSampleCount,
      discardedSampleCount: _discardedSampleCount,
      score: score,
      baselineEnergyCost: baselineEnergyCost,
      potentialSaving: potentialSaving,
      recommendations: _recommendations(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        idleRatio: idleRatio,
      ),
    );
  }

  List<String> _recommendations({
    required double distanceKm,
    required int durationSeconds,
    required double idleRatio,
  }) {
    if (distanceKm < 0.5 || durationSeconds < 120) {
      return const [
        'Trajet trop court pour produire une estimation financière fiable.',
      ];
    }

    final messages = <String>[];
    if (_harshAccelerationCount > 0) {
      messages.add(
        'Accélérez plus progressivement lorsque les conditions le permettent.',
      );
    }
    if (_harshBrakingCount > 0) {
      messages.add(
        'Anticipez davantage les ralentissements pour limiter les freinages forts.',
      );
    }
    if (idleRatio > 0.15) {
      messages.add(
        'Réduisez les phases d’arrêt moteur tournant lorsque cela est possible.',
      );
    }
    if (messages.isEmpty) {
      messages.add(
        'Votre conduite est régulière sur ce trajet. Continuez ainsi.',
      );
    }
    return List.unmodifiable(messages);
  }

  static bool _isValidSample(EcoDrivingSample sample) {
    return sample.latitude.isFinite &&
        sample.latitude >= -90 &&
        sample.latitude <= 90 &&
        sample.longitude.isFinite &&
        sample.longitude >= -180 &&
        sample.longitude <= 180 &&
        sample.accuracyMeters.isFinite &&
        sample.accuracyMeters >= 0 &&
        sample.accuracyMeters <= maximumAcceptedAccuracyMeters &&
        sample.speedMps.isFinite &&
        sample.speedMps <= maximumAcceptedSpeedMps;
  }

  static double _normalizedSpeed(double speedMps, {required double fallback}) {
    if (!speedMps.isFinite || speedMps < 0) return fallback;
    return speedMps.clamp(0, maximumAcceptedSpeedMps).toDouble();
  }

  static void _validateProfile(EcoDrivingProfile profile) {
    if (profile.consumptionPer100Km <= 0 ||
        profile.consumptionPer100Km > 100 ||
        profile.energyPrice < 0 ||
        profile.energyPrice > 10 ||
        profile.potentialGainPercent < 0 ||
        profile.potentialGainPercent > 15) {
      throw const FormatException(
        'Le profil d’écoconduite contient une valeur invalide.',
      );
    }
  }
}

double distanceBetweenMeters(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _radians(latitude2 - latitude1);
  final longitudeDelta = _radians(longitude2 - longitude1);
  final startLatitude = _radians(latitude1);
  final endLatitude = _radians(latitude2);

  final haversine =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(startLatitude) *
          math.cos(endLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  final normalizedHaversine = haversine.clamp(0, 1).toDouble();
  final centralAngle =
      2 *
      math.atan2(
        math.sqrt(normalizedHaversine),
        math.sqrt(1 - normalizedHaversine),
      );
  return earthRadiusMeters * centralAngle;
}

double _radians(double degrees) => degrees * math.pi / 180;
