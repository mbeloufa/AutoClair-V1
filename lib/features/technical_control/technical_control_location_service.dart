import 'dart:async';

import 'package:geolocator/geolocator.dart';

class TechnicalControlLocationException implements Exception {
  const TechnicalControlLocationException(
    this.message, {
    this.settingsRequired = false,
    this.openLocationServices = false,
  });

  final String message;
  final bool settingsRequired;
  final bool openLocationServices;
}

class TechnicalControlLocationService {
  Future<Position> determineCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const TechnicalControlLocationException(
        'Activez la localisation de votre appareil pour rechercher les centres proches.',
        settingsRequired: true,
        openLocationServices: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const TechnicalControlLocationException(
        'La localisation est nécessaire pour calculer la distance des centres.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const TechnicalControlLocationException(
        "L'accès à la localisation est bloqué. Autorisez-le dans les réglages de l'appareil.",
        settingsRequired: true,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      throw const TechnicalControlLocationException(
        "La position n'a pas pu être obtenue assez rapidement. Réessayez à l'extérieur.",
      );
    } catch (_) {
      throw const TechnicalControlLocationException(
        "La position de l'appareil n'a pas pu être déterminée.",
      );
    }
  }

  Future<bool> openSettings({required bool locationServices}) {
    return locationServices
        ? Geolocator.openLocationSettings()
        : Geolocator.openAppSettings();
  }
}
