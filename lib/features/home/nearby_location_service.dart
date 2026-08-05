import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../technical_control/technical_control_location_service.dart';
import 'nearby_location.dart';

class NearbyLocationSearchException implements Exception {
  const NearbyLocationSearchException(this.message);

  final String message;
}

class NearbyLocationService {
  NearbyLocationService._({http.Client? client})
    : _client = client ?? http.Client();

  static final NearbyLocationService instance = NearbyLocationService._();

  final http.Client _client;
  final TechnicalControlLocationService _deviceLocationService =
      TechnicalControlLocationService();

  NearbySearchLocation? _sessionLocation;

  NearbySearchLocation? get sessionLocation => _sessionLocation;

  void remember(NearbySearchLocation location) {
    if (!location.hasValidCoordinates) return;
    _sessionLocation = location;
  }

  void clearRememberedLocation() {
    _sessionLocation = null;
  }

  Future<NearbySearchLocation> useCurrentLocation() async {
    final position = await _deviceLocationService.determineCurrentPosition();
    final location = NearbySearchLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      label: 'Ma position',
      isDevicePosition: true,
    );
    remember(location);
    return location;
  }

  Future<NearbySearchLocation> resolveSearchLocation() async {
    final remembered = _sessionLocation;
    if (remembered != null) return remembered;
    return useCurrentLocation();
  }

  Future<bool> openSettings({required bool locationServices}) {
    return _deviceLocationService.openSettings(
      locationServices: locationServices,
    );
  }

  Future<List<NearbyLocationSuggestion>> searchLocations(String query) async {
    final normalized = query.trim();
    if (normalized.length < 3) {
      throw const NearbyLocationSearchException(
        'Saisissez au moins trois caractères.',
      );
    }

    final uri = Uri.https('data.geopf.fr', '/geocodage/search', {
      'q': normalized,
      'limit': '6',
    });

    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 429) {
        throw const NearbyLocationSearchException(
          'Le service de localisation est temporairement très sollicité. Réessayez dans quelques secondes.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const NearbyLocationSearchException(
          "La recherche d'adresse n'est pas disponible pour le moment.",
        );
      }

      final decoded = jsonDecode(response.body);
      final suggestions = parseFeatureCollection(decoded);
      if (suggestions.isEmpty) {
        throw const NearbyLocationSearchException(
          'Aucun lieu correspondant n’a été trouvé.',
        );
      }
      return suggestions;
    } on TimeoutException {
      throw const NearbyLocationSearchException(
        'La recherche prend trop de temps. Vérifiez votre connexion.',
      );
    } on NearbyLocationSearchException {
      rethrow;
    } on FormatException {
      throw const NearbyLocationSearchException(
        'La réponse du service de localisation est invalide.',
      );
    } catch (_) {
      throw const NearbyLocationSearchException(
        "La recherche d'adresse n'a pas pu aboutir.",
      );
    }
  }

  static List<NearbyLocationSuggestion> parseFeatureCollection(Object? raw) {
    if (raw is! Map) return const [];
    final features = raw['features'];
    if (features is! List) return const [];

    final suggestions = <NearbyLocationSuggestion>[];
    final seen = <String>{};

    for (final feature in features) {
      if (feature is! Map) continue;
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry is! Map || properties is! Map) continue;

      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;

      final longitude = _asDouble(coordinates[0]);
      final latitude = _asDouble(coordinates[1]);
      if (latitude == null || longitude == null) continue;

      final label = _firstText([
        properties['label'],
        properties['name'],
        properties['toponym'],
      ]);
      if (label == null) continue;

      final city = _firstText([properties['city'], properties['municipality']]);
      final postcode = _firstText([
        properties['postcode'],
        properties['postalcode'],
      ]);
      final secondary = [
        postcode,
        city,
      ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

      final key =
          '${latitude.toStringAsFixed(6)}:'
          '${longitude.toStringAsFixed(6)}';
      if (!seen.add(key)) continue;

      final suggestion = NearbyLocationSuggestion(
        latitude: latitude,
        longitude: longitude,
        label: label,
        secondaryLabel: secondary.isEmpty ? null : secondary,
        score: _asDouble(properties['score']),
      );
      if (suggestion.hasValidCoordinates) suggestions.add(suggestion);
    }

    suggestions.sort((left, right) {
      final leftScore = left.score ?? 0;
      final rightScore = right.score ?? 0;
      return rightScore.compareTo(leftScore);
    });
    return suggestions;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _firstText(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
