class NearbySearchLocation {
  const NearbySearchLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.isDevicePosition = false,
  });

  final double latitude;
  final double longitude;
  final String label;
  final bool isDevicePosition;

  bool get hasValidCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

class NearbyLocationSuggestion extends NearbySearchLocation {
  const NearbyLocationSuggestion({
    required super.latitude,
    required super.longitude,
    required super.label,
    this.secondaryLabel,
    this.score,
  });

  final String? secondaryLabel;
  final double? score;
}
