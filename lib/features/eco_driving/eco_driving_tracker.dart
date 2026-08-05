import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'eco_driving_calculator.dart';
import 'eco_driving_models.dart';

class EcoDrivingTrackerException implements Exception {
  const EcoDrivingTrackerException(
    this.message, {
    this.settingsRequired = false,
    this.openLocationServices = false,
  });

  final String message;
  final bool settingsRequired;
  final bool openLocationServices;
}

class EcoDrivingTracker {
  StreamSubscription<Position>? _subscription;
  EcoDrivingTripAnalyzer? _analyzer;

  bool get isTracking => _subscription != null && _analyzer != null;

  Future<void> start({
    required void Function(EcoDrivingLiveMetrics metrics) onMetrics,
    required void Function(String message) onError,
  }) async {
    if (isTracking) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const EcoDrivingTrackerException(
        'Activez la localisation pour analyser ce trajet.',
        settingsRequired: true,
        openLocationServices: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const EcoDrivingTrackerException(
        'Autorisez la localisation pendant l’utilisation pour analyser ce trajet.',
        settingsRequired: true,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const EcoDrivingTrackerException(
        'La localisation est bloquée dans les réglages de l’application.',
        settingsRequired: true,
      );
    }

    final analyzer = EcoDrivingTripAnalyzer();
    _analyzer = analyzer;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) {
            final metrics = analyzer.addSample(
              EcoDrivingSample(
                timestamp: position.timestamp,
                latitude: position.latitude,
                longitude: position.longitude,
                speedMps: position.speed,
                accuracyMeters: position.accuracy,
              ),
            );
            onMetrics(metrics);
          },
          onError: (Object _) {
            onError(
              'La mesure du trajet a été interrompue par la localisation.',
            );
          },
        );
  }

  Future<EcoDrivingSessionSummary> stop({
    required EcoDrivingProfile profile,
  }) async {
    final analyzer = _analyzer;
    if (analyzer == null) {
      throw const EcoDrivingTrackerException('Aucun trajet n’est en cours.');
    }

    await _subscription?.cancel();
    _subscription = null;
    _analyzer = null;
    return analyzer.finish(profile: profile);
  }

  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    _analyzer = null;
  }

  Future<bool> openSettings({required bool locationServices}) {
    return locationServices
        ? Geolocator.openLocationSettings()
        : Geolocator.openAppSettings();
  }
}
