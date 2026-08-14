class SmartTripPoint {
  const SmartTripPoint({required this.lat, required this.lng});

  factory SmartTripPoint.fromJson(Map<String, dynamic> json) {
    return SmartTripPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

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

  factory SmartTripPlace.fromJson(Map<String, dynamic> json) {
    return SmartTripPlace(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }

  final String label;
}

class SmartTripSuggestion extends SmartTripPlace {
  const SmartTripSuggestion({
    required super.lat,
    required super.lng,
    required super.label,
    required this.id,
    required this.subtitle,
  });

  factory SmartTripSuggestion.fromJson(Map<String, dynamic> json) {
    return SmartTripSuggestion(
      id: json['id']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
    );
  }

  final String id;
  final String subtitle;
}

class SmartTripRoute {
  const SmartTripRoute({
    required this.id,
    required this.label,
    required this.strategy,
    required this.complexitySteps,
    required this.distanceKm,
    required this.durationMinutes,
    required this.tollEur,
    required this.energyQuantity,
    required this.energyCostEur,
    required this.totalCostEur,
  });

  factory SmartTripRoute.fromJson(Map<String, dynamic> json) {
    return SmartTripRoute(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      strategy: json['strategy']?.toString() ?? '',
      complexitySteps: (json['complexity_steps'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toDouble() ?? 0,
      tollEur: (json['toll_eur'] as num?)?.toDouble() ?? 0,
      energyQuantity: (json['energy_quantity'] as num?)?.toDouble() ?? 0,
      energyCostEur: (json['energy_cost_eur'] as num?)?.toDouble() ?? 0,
      totalCostEur: (json['total_cost_eur'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String label;
  final String strategy;
  final int complexitySteps;
  final double distanceKm;
  final double durationMinutes;
  final double tollEur;
  final double energyQuantity;
  final double energyCostEur;
  final double totalCostEur;
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

  factory SmartTripComparison.fromJson(Map<String, dynamic> json) {
    return SmartTripComparison(
      extraMinutes: (json['extra_minutes'] as num?)?.toDouble() ?? 0,
      extraKm: (json['extra_km'] as num?)?.toDouble() ?? 0,
      tollSavingEur: (json['toll_saving_eur'] as num?)?.toDouble() ?? 0,
      energyCostDeltaEur:
          (json['energy_cost_delta_eur'] as num?)?.toDouble() ?? 0,
      netSavingEur: (json['net_saving_eur'] as num?)?.toDouble() ?? 0,
      percentSaving: (json['percent_saving'] as num?)?.toDouble() ?? 0,
    );
  }

  final double extraMinutes;
  final double extraKm;
  final double tollSavingEur;
  final double energyCostDeltaEur;
  final double netSavingEur;
  final double percentSaving;
}

class SmartTripFuelReference {
  const SmartTripFuelReference({
    required this.priceEurPerL,
    required this.fuelType,
    required this.source,
    required this.sampleCount,
    required this.sourceFetchedAt,
  });

  factory SmartTripFuelReference.fromJson(Map<String, dynamic> json) {
    return SmartTripFuelReference(
      priceEurPerL: (json['price_eur_per_l'] as num?)?.toDouble() ?? 0,
      fuelType: json['fuel_type']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      sourceFetchedAt: json['source_fetched_at']?.toString(),
    );
  }

  final double priceEurPerL;
  final String fuelType;
  final String source;
  final int sampleCount;
  final String? sourceFetchedAt;
}

class SmartTripConsumptionReference {
  const SmartTripConsumptionReference({
    required this.consumptionPer100,
    required this.source,
  });

  factory SmartTripConsumptionReference.fromJson(Map<String, dynamic> json) {
    return SmartTripConsumptionReference(
      consumptionPer100: (json['consumption_per_100'] as num?)?.toDouble() ?? 0,
      source: json['source']?.toString() ?? '',
    );
  }

  final double consumptionPer100;
  final String source;

  bool get isEstimated => source == 'ESTIMATED_BY_FUEL';
}

class SmartTripResult {
  const SmartTripResult({
    required this.status,
    required this.requestId,
    required this.method,
    required this.origin,
    required this.destination,
    required this.fuelReference,
    required this.consumptionReference,
    required this.baseline,
    required this.recommended,
    required this.comparison,
    required this.navigationWaypoints,
    required this.testedRoutes,
    required this.paretoRoutes,
    required this.routeRequests,
  });

  factory SmartTripResult.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapOf(Object? value) {
      return value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
    }

    final rawWaypoints = json['navigation_waypoints'];
    return SmartTripResult(
      status: json['status']?.toString() ?? 'BASELINE_BEST',
      requestId: json['request_id']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      origin: SmartTripPlace.fromJson(mapOf(json['origin'])),
      destination: SmartTripPlace.fromJson(mapOf(json['destination'])),
      fuelReference: SmartTripFuelReference.fromJson(
        mapOf(json['fuel_price_reference']),
      ),
      consumptionReference: SmartTripConsumptionReference.fromJson(
        mapOf(json['consumption_reference']),
      ),
      baseline: SmartTripRoute.fromJson(mapOf(json['baseline'])),
      recommended: SmartTripRoute.fromJson(mapOf(json['recommended'])),
      comparison: SmartTripComparison.fromJson(mapOf(json['comparison'])),
      navigationWaypoints: rawWaypoints is List
          ? rawWaypoints
                .whereType<Map>()
                .map(
                  (item) =>
                      SmartTripPoint.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      testedRoutes: (json['tested_routes'] as num?)?.toInt() ?? 0,
      paretoRoutes: (json['pareto_routes'] as num?)?.toInt() ?? 0,
      routeRequests: (json['route_requests'] as num?)?.toInt() ?? 0,
    );
  }

  final String status;
  final String requestId;
  final String method;
  final SmartTripPlace origin;
  final SmartTripPlace destination;
  final SmartTripFuelReference fuelReference;
  final SmartTripConsumptionReference consumptionReference;
  final SmartTripRoute baseline;
  final SmartTripRoute recommended;
  final SmartTripComparison comparison;
  final List<SmartTripPoint> navigationWaypoints;
  final int testedRoutes;
  final int paretoRoutes;
  final int routeRequests;

  bool get hasSaving {
    return status == 'SAVING_FOUND' && comparison.netSavingEur > 0;
  }
}
