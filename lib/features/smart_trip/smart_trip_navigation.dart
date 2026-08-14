bool supportsAppleSmartTripWaypoints({
  required bool isIOS,
  required String operatingSystemVersion,
}) {
  if (!isIOS) {
    return false;
  }

  RegExpMatch? match = RegExp(
    r'Version\s+(\d+)(?:\.(\d+))?',
    caseSensitive: false,
  ).firstMatch(operatingSystemVersion);

  match ??= RegExp(
    r'\b(\d+)\.(\d+)(?:\.\d+)?\b',
  ).firstMatch(operatingSystemVersion);

  if (match == null) {
    return false;
  }

  final major = int.tryParse(match.group(1) ?? '') ?? 0;
  final minor = int.tryParse(match.group(2) ?? '') ?? 0;
  return major > 18 || (major == 18 && minor >= 4);
}

List<String> _smartTripWaypoints(Iterable<String> waypoints) {
  return waypoints
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .take(3)
      .toList(growable: false);
}

Uri buildSmartTripGoogleMapsUri({
  required String origin,
  required String destination,
  Iterable<String> waypoints = const <String>[],
}) {
  final safeWaypoints = _smartTripWaypoints(waypoints);
  return Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'origin': origin,
    'destination': destination,
    'travelmode': 'driving',
    'dir_action': 'navigate',
    if (safeWaypoints.isNotEmpty) 'waypoints': safeWaypoints.join('|'),
  });
}

Uri buildSmartTripAppleMapsUri({
  required String origin,
  required String destination,
  Iterable<String> waypoints = const <String>[],
  required bool supportsWaypoints,
}) {
  if (!supportsWaypoints) {
    return Uri.https('maps.apple.com', '/', <String, String>{
      'saddr': origin,
      'daddr': destination,
      'dirflg': 'd',
    });
  }

  final safeWaypoints = _smartTripWaypoints(waypoints);
  final query = <String>[
    'source=${Uri.encodeQueryComponent(origin)}',
    'destination=${Uri.encodeQueryComponent(destination)}',
    for (final waypoint in safeWaypoints)
      'waypoint=${Uri.encodeQueryComponent(waypoint)}',
    'mode=driving',
    'start=0',
  ];

  return Uri.parse('https://maps.apple.com/directions?${query.join('&')}');
}

Uri buildSmartTripWazeUri({required String destination}) {
  return Uri.https('www.waze.com', '/ul', <String, String>{
    'll': destination,
    'navigate': 'yes',
  });
}
