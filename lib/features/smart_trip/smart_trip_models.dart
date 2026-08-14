class SmartTripPoint {
  const SmartTripPoint({required this.lat, required this.lng});
  factory SmartTripPoint.fromJson(Map<String, dynamic> json) => SmartTripPoint(
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0,
  );
  final double lat;
  final double lng;
  String get coordinate => '$lat,$lng';
}

class SmartTripPlace extends SmartTripPoint {
  const SmartTripPlace({
    required super.lat,
    required super.lng,
    required this.label,
  });
  factory SmartTripPlace.fromJson(Map<String, dynamic> json) => SmartTripPlace(
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0,
    label: json['label']?.toString() ?? '',
  );
  final String label;
}

class SmartTripRoute {
  const SmartTripRoute({
    required this.id,
    required this.label,
    required this.distanceKm,
    required this.durationMinutes,
    required this.tollEur,
    required this.energyQuantity,
    required this.energyCostEur,
    required this.totalCostEur,
  });
  factory SmartTripRoute.fromJson(Map<String, dynamic> j) => SmartTripRoute(
    id: j['id']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
    durationMinutes: (j['duration_minutes'] as num?)?.toDouble() ?? 0,
    tollEur: (j['toll_eur'] as num?)?.toDouble() ?? 0,
    energyQuantity: (j['energy_quantity'] as num?)?.toDouble() ?? 0,
    energyCostEur: (j['energy_cost_eur'] as num?)?.toDouble() ?? 0,
    totalCostEur: (j['total_cost_eur'] as num?)?.toDouble() ?? 0,
  );
  final String id, label;
  final double distanceKm,
      durationMinutes,
      tollEur,
      energyQuantity,
      energyCostEur,
      totalCostEur;
}

class SmartTripComparison {
  const SmartTripComparison({
    required this.extraMinutes,
    required this.extraKm,
    required this.tollSavingEur,
    required this.energyCostDeltaEur,
    required this.netSavingEur,
    required this.percentSaving,
  });
  factory SmartTripComparison.fromJson(Map<String, dynamic> j) =>
      SmartTripComparison(
        extraMinutes: (j['extra_minutes'] as num?)?.toDouble() ?? 0,
        extraKm: (j['extra_km'] as num?)?.toDouble() ?? 0,
        tollSavingEur: (j['toll_saving_eur'] as num?)?.toDouble() ?? 0,
        energyCostDeltaEur:
            (j['energy_cost_delta_eur'] as num?)?.toDouble() ?? 0,
        netSavingEur: (j['net_saving_eur'] as num?)?.toDouble() ?? 0,
        percentSaving: (j['percent_saving'] as num?)?.toDouble() ?? 0,
      );
  final double extraMinutes,
      extraKm,
      tollSavingEur,
      energyCostDeltaEur,
      netSavingEur,
      percentSaving;
}

class SmartTripResult {
  const SmartTripResult({
    required this.status,
    required this.requestId,
    required this.origin,
    required this.destination,
    required this.baseline,
    required this.recommended,
    required this.comparison,
    required this.navigationWaypoints,
    required this.testedRoutes,
  });
  factory SmartTripResult.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final raw = j['navigation_waypoints'];
    return SmartTripResult(
      status: j['status']?.toString() ?? 'BASELINE_BEST',
      requestId: j['request_id']?.toString() ?? '',
      origin: SmartTripPlace.fromJson(m(j['origin'])),
      destination: SmartTripPlace.fromJson(m(j['destination'])),
      baseline: SmartTripRoute.fromJson(m(j['baseline'])),
      recommended: SmartTripRoute.fromJson(m(j['recommended'])),
      comparison: SmartTripComparison.fromJson(m(j['comparison'])),
      navigationWaypoints: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (x) => SmartTripPoint.fromJson(Map<String, dynamic>.from(x)),
                )
                .toList(growable: false)
          : const [],
      testedRoutes: (j['tested_routes'] as num?)?.toInt() ?? 0,
    );
  }
  final String status, requestId;
  final SmartTripPlace origin, destination;
  final SmartTripRoute baseline, recommended;
  final SmartTripComparison comparison;
  final List<SmartTripPoint> navigationWaypoints;
  final int testedRoutes;
  bool get hasSaving => status == 'SAVING_FOUND' && comparison.netSavingEur > 0;
}
