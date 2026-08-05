import '../../core/finance/saving_status.dart';

class VehicleCostEntry {
  const VehicleCostEntry({
    required this.id,
    required this.vehicleId,
    required this.category,
    required this.subcategory,
    required this.amount,
    required this.eventDate,
    required this.sourceType,
    this.mileageKm,
    this.note,
    this.sourceReference,
  });

  final String id;
  final String vehicleId;
  final String category;
  final String subcategory;
  final double amount;
  final DateTime eventDate;
  final String sourceType;
  final int? mileageKm;
  final String? note;
  final String? sourceReference;

  String get categoryLabel => switch (category.toUpperCase()) {
    'FUEL' => 'Carburant',
    'CHARGING' => 'Recharge',
    'MAINTENANCE' => 'Entretien',
    'REPAIR' => 'Réparation',
    'INSURANCE' => 'Assurance',
    'TECHNICAL_CONTROL' => 'Contrôle technique',
    'PARKING' => 'Parking',
    'TOLL' => 'Péage',
    'ACCESSORIES' => 'Accessoires',
    _ => 'Autre',
  };

  factory VehicleCostEntry.fromMap(Map<String, dynamic> map) {
    return VehicleCostEntry(
      id: map['id']?.toString() ?? '',
      vehicleId: map['vehicle_id']?.toString() ?? '',
      category: map['category']?.toString() ?? 'OTHER',
      subcategory: map['subcategory']?.toString() ?? 'Autre',
      amount: _decimal(map['amount']),
      eventDate:
          DateTime.tryParse(map['event_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sourceType: map['source_type']?.toString() ?? 'MANUAL',
      mileageKm: _integer(map['mileage_km']),
      note: _text(map['note']),
      sourceReference: _text(map['source_reference']),
    );
  }
}

class SavingOpportunitySummary {
  const SavingOpportunitySummary({
    required this.id,
    required this.featureCode,
    required this.baselineAmount,
    required this.proposedAmount,
    required this.potentialSaving,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
  });

  final String id;
  final String featureCode;
  final double baselineAmount;
  final double proposedAmount;
  final double potentialSaving;
  final SavingStatus status;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  String get featureLabel => switch (featureCode) {
    'FUEL_OPTIMIZER' => 'Optimiseur de plein',
    'QUOTE_COMPARISON' => 'Comparaison de devis',
    'INSURANCE_REVIEW' => 'Révision assurance',
    'CHARGING_OPTIMIZER' => 'Optimiseur de recharge',
    _ => 'Économie AutoClair',
  };

  factory SavingOpportunitySummary.fromMap(Map<String, dynamic> map) {
    return SavingOpportunitySummary(
      id: map['id']?.toString() ?? '',
      featureCode: map['feature_code']?.toString() ?? 'OTHER',
      baselineAmount: _decimal(map['baseline_amount']),
      proposedAmount: _decimal(map['proposed_amount']),
      potentialSaving: _decimal(map['potential_saving']),
      status: SavingStatus.fromDatabase(map['status']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      confirmedAt: DateTime.tryParse(map['confirmed_at']?.toString() ?? ''),
    );
  }
}

class VehicleBudgetSummary {
  const VehicleBudgetSummary({
    required this.entries,
    required this.opportunities,
    required this.totalLast12Months,
    required this.monthlyAverage,
    required this.byCategory,
    required this.confirmedSavings,
    required this.potentialSavings,
    this.costPerKm,
    this.coveredDistanceKm,
  });

  final List<VehicleCostEntry> entries;
  final List<SavingOpportunitySummary> opportunities;
  final double totalLast12Months;
  final double monthlyAverage;
  final Map<String, double> byCategory;
  final double confirmedSavings;
  final double potentialSavings;
  final double? costPerKm;
  final int? coveredDistanceKm;

  factory VehicleBudgetSummary.calculate({
    required List<VehicleCostEntry> entries,
    required List<SavingOpportunitySummary> opportunities,
    int? distanceKm,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final start = DateTime(reference.year - 1, reference.month, reference.day);
    final recentEntries = entries
        .where((entry) => !entry.eventDate.isBefore(start))
        .toList(growable: false);
    final total = recentEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final byCategory = <String, double>{};
    for (final entry in recentEntries) {
      byCategory.update(
        entry.category,
        (current) => current + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }

    final confirmed = opportunities
        .where((item) => item.status == SavingStatus.confirmed)
        .fold<double>(0, (sum, item) => sum + item.potentialSaving);
    final potential = opportunities
        .where(
          (item) =>
              item.status == SavingStatus.detected ||
              item.status == SavingStatus.accepted,
        )
        .fold<double>(0, (sum, item) => sum + item.potentialSaving);

    final validDistance = distanceKm != null && distanceKm > 0
        ? distanceKm
        : null;

    return VehicleBudgetSummary(
      entries: List.unmodifiable(entries),
      opportunities: List.unmodifiable(opportunities),
      totalLast12Months: total,
      monthlyAverage: total / 12,
      byCategory: Map.unmodifiable(byCategory),
      confirmedSavings: confirmed,
      potentialSavings: potential,
      costPerKm: validDistance == null ? null : total / validDistance,
      coveredDistanceKm: validDistance,
    );
  }
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
