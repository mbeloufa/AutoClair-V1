class VehicleCareDashboard {
  const VehicleCareDashboard({
    required this.health,
    required this.upcomingActions,
    required this.recalls,
    required this.risks,
    required this.recentEvents,
    required this.expenses,
    required this.generatedAt,
  });

  final VehicleHealthSummary health;
  final List<VehicleReminder> upcomingActions;
  final List<VehicleRecallAlert> recalls;
  final List<VehicleRiskAlert> risks;
  final List<VehicleTimelineEvent> recentEvents;
  final VehicleExpenseSummary expenses;
  final DateTime? generatedAt;

  factory VehicleCareDashboard.fromMap(Map<String, dynamic> map) {
    return VehicleCareDashboard(
      health: VehicleHealthSummary.fromMap(_map(map['health'])),
      upcomingActions: _list(
        map['upcoming_actions'],
      ).map(VehicleReminder.fromMap).toList(growable: false),
      recalls: _list(
        map['recalls'],
      ).map(VehicleRecallAlert.fromMap).toList(growable: false),
      risks: _list(
        map['risks'],
      ).map(VehicleRiskAlert.fromMap).toList(growable: false),
      recentEvents: _list(
        map['recent_events'],
      ).map(VehicleTimelineEvent.fromMap).toList(growable: false),
      expenses: VehicleExpenseSummary.fromMap(_map(map['expenses'])),
      generatedAt: _dateTime(map['generated_at']),
    );
  }
}

class VehicleHealthSummary {
  const VehicleHealthSummary({
    required this.maintenanceScore,
    required this.safetyScore,
    required this.administrativeScore,
    required this.historyScore,
    required this.budgetTrackingScore,
    required this.saleReadinessScore,
    required this.overallStatus,
    required this.reasons,
    required this.metrics,
  });

  final int maintenanceScore;
  final int safetyScore;
  final int administrativeScore;
  final int historyScore;
  final int budgetTrackingScore;
  final int saleReadinessScore;
  final String overallStatus;
  final Map<String, dynamic> reasons;
  final Map<String, dynamic> metrics;

  factory VehicleHealthSummary.fromMap(Map<String, dynamic> map) {
    return VehicleHealthSummary(
      maintenanceScore: _integer(map['maintenance_score']),
      safetyScore: _integer(map['safety_score']),
      administrativeScore: _integer(map['administrative_score']),
      historyScore: _integer(map['history_score']),
      budgetTrackingScore: _integer(map['budget_tracking_score']),
      saleReadinessScore: _integer(map['sale_readiness_score']),
      overallStatus: _text(map['overall_status'], fallback: 'INCOMPLETE'),
      reasons: _map(map['reasons']),
      metrics: _map(map['metrics']),
    );
  }

  String get statusLabel => switch (overallStatus) {
    'GOOD' => 'Suivi satisfaisant',
    'WATCH' => 'Points à surveiller',
    'ACTION_NEEDED' => 'Actions nécessaires',
    _ => 'Dossier à compléter',
  };
}

class VehicleReminder {
  const VehicleReminder({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.message,
    required this.priority,
    required this.status,
    this.dueAt,
    this.dueMileage,
  });

  final String id;
  final String sourceType;
  final String title;
  final String message;
  final String priority;
  final String status;
  final DateTime? dueAt;
  final int? dueMileage;

  factory VehicleReminder.fromMap(Map<String, dynamic> map) {
    return VehicleReminder(
      id: _text(map['id']),
      sourceType: _text(map['source_type']),
      title: _text(map['title'], fallback: 'Échéance'),
      message: _text(map['message']),
      priority: _text(map['priority'], fallback: 'MEDIUM'),
      status: _text(map['status'], fallback: 'ACTIVE'),
      dueAt: _dateTime(map['due_at']),
      dueMileage: _nullableInteger(map['due_mileage']),
    );
  }
}

class VehicleRecallAlert {
  const VehicleRecallAlert({
    required this.matchId,
    required this.status,
    required this.matchScore,
    required this.title,
    required this.brand,
    required this.modelsReferences,
    required this.risks,
    required this.consumerActions,
    required this.matchReason,
    this.publicationDate,
    this.recallUrl,
  });

  final String matchId;
  final String status;
  final double matchScore;
  final String title;
  final String brand;
  final String modelsReferences;
  final String risks;
  final String consumerActions;
  final String matchReason;
  final DateTime? publicationDate;
  final String? recallUrl;

  factory VehicleRecallAlert.fromMap(Map<String, dynamic> map) {
    return VehicleRecallAlert(
      matchId: _text(map['match_id']),
      status: _text(map['status'], fallback: 'TO_CHECK'),
      matchScore: _decimal(map['match_score']),
      title: _text(map['title'], fallback: 'Rappel à vérifier'),
      brand: _text(map['brand']),
      modelsReferences: _text(map['models_references']),
      risks: _text(map['risks']),
      consumerActions: _text(map['consumer_actions']),
      matchReason: _text(map['match_reason']),
      publicationDate: _dateTime(map['publication_date']),
      recallUrl: _nullableText(map['recall_url']),
    );
  }

  String get statusLabel => switch (status) {
    'POSSIBLE' => 'Potentiellement concerné',
    'SCHEDULED' => 'Intervention programmée',
    'COMPLETED' => 'Rappel effectué',
    'NOT_CONCERNED' => 'Non concerné',
    _ => 'À vérifier',
  };
}

class VehicleRiskAlert {
  const VehicleRiskAlert({
    required this.matchId,
    required this.status,
    required this.matchScore,
    required this.title,
    required this.description,
    required this.severity,
    required this.confidence,
    required this.recommendedAction,
    required this.sourceName,
    this.mileageMin,
    this.mileageMax,
    this.sourceUrl,
  });

  final String matchId;
  final String status;
  final double matchScore;
  final String title;
  final String description;
  final String severity;
  final String confidence;
  final int? mileageMin;
  final int? mileageMax;
  final String recommendedAction;
  final String sourceName;
  final String? sourceUrl;

  factory VehicleRiskAlert.fromMap(Map<String, dynamic> map) {
    return VehicleRiskAlert(
      matchId: _text(map['match_id']),
      status: _text(map['status'], fallback: 'ACTIVE'),
      matchScore: _decimal(map['match_score']),
      title: _text(map['title'], fallback: 'Point de vigilance'),
      description: _text(map['description']),
      severity: _text(map['severity'], fallback: 'MEDIUM'),
      confidence: _text(map['confidence'], fallback: 'MEDIUM'),
      mileageMin: _nullableInteger(map['mileage_min']),
      mileageMax: _nullableInteger(map['mileage_max']),
      recommendedAction: _text(map['recommended_action']),
      sourceName: _text(map['source_name']),
      sourceUrl: _nullableText(map['source_url']),
    );
  }
}

class VehicleTimelineEvent {
  const VehicleTimelineEvent({
    required this.id,
    required this.eventType,
    required this.status,
    required this.title,
    required this.occurredAt,
    required this.sourceType,
    required this.userConfirmed,
    this.description,
    this.mileage,
    this.amount,
    this.currency,
    this.providerName,
  });

  final String id;
  final String eventType;
  final String status;
  final String title;
  final DateTime occurredAt;
  final String sourceType;
  final bool userConfirmed;
  final String? description;
  final int? mileage;
  final double? amount;
  final String? currency;
  final String? providerName;

  factory VehicleTimelineEvent.fromMap(Map<String, dynamic> map) {
    return VehicleTimelineEvent(
      id: _text(map['id']),
      eventType: _text(map['event_type'], fallback: 'OTHER'),
      status: _text(map['status'], fallback: 'COMPLETED'),
      title: _text(map['title'], fallback: 'Événement'),
      occurredAt:
          _dateTime(map['occurred_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sourceType: _text(map['source_type'], fallback: 'MANUAL'),
      userConfirmed: map['user_confirmed'] as bool? ?? false,
      description: _nullableText(map['description']),
      mileage: _nullableInteger(map['mileage']),
      amount: _nullableDecimal(map['amount']),
      currency: _nullableText(map['currency']),
      providerName: _nullableText(map['provider_name']),
    );
  }

  String get typeLabel => eventTypeLabel(eventType);
}

class VehicleExpenseSummary {
  const VehicleExpenseSummary({
    required this.totalLast12Months,
    required this.totalAllTime,
    required this.byCategory,
  });

  final double totalLast12Months;
  final double totalAllTime;
  final Map<String, double> byCategory;

  factory VehicleExpenseSummary.fromMap(Map<String, dynamic> map) {
    final rawCategories = _map(map['by_category']);
    return VehicleExpenseSummary(
      totalLast12Months: _decimal(map['total_last_12_months']),
      totalAllTime: _decimal(map['total_all_time']),
      byCategory: rawCategories.map(
        (key, value) => MapEntry(key, _decimal(value)),
      ),
    );
  }
}

class VehicleMaintenanceSchedule {
  const VehicleMaintenanceSchedule({
    required this.id,
    required this.title,
    required this.scheduleType,
    required this.status,
    required this.priority,
    required this.sourceType,
    required this.reason,
    this.dueDate,
    this.dueMileage,
    this.intervalMonths,
    this.intervalKm,
  });

  final String id;
  final String title;
  final String scheduleType;
  final String status;
  final String priority;
  final String sourceType;
  final String reason;
  final DateTime? dueDate;
  final int? dueMileage;
  final int? intervalMonths;
  final int? intervalKm;

  factory VehicleMaintenanceSchedule.fromMap(Map<String, dynamic> map) {
    return VehicleMaintenanceSchedule(
      id: _text(map['id']),
      title: _text(map['title'], fallback: 'Entretien'),
      scheduleType: _text(map['schedule_type'], fallback: 'MAINTENANCE'),
      status: _text(map['status'], fallback: 'ACTIVE'),
      priority: _text(map['priority'], fallback: 'MEDIUM'),
      sourceType: _text(map['source_type'], fallback: 'AUTOCLAIR_RULE'),
      reason: _text(map['reason']),
      dueDate: _dateTime(map['due_date']),
      dueMileage: _nullableInteger(map['due_mileage']),
      intervalMonths: _nullableInteger(map['interval_months']),
      intervalKm: _nullableInteger(map['interval_km']),
    );
  }

  bool isOverdue({required int? currentMileage, DateTime? now}) {
    final reference = now ?? DateTime.now();
    final dateOverdue =
        dueDate != null &&
        DateTime(
          dueDate!.year,
          dueDate!.month,
          dueDate!.day,
        ).isBefore(DateTime(reference.year, reference.month, reference.day));
    final mileageOverdue =
        dueMileage != null &&
        currentMileage != null &&
        dueMileage! <= currentMileage;
    return dateOverdue || mileageOverdue;
  }

  bool isDueSoon({required int? currentMileage, DateTime? now}) {
    if (isOverdue(currentMileage: currentMileage, now: now)) return false;
    final reference = now ?? DateTime.now();
    final dateSoon =
        dueDate != null &&
        dueDate!.isBefore(reference.add(const Duration(days: 31)));
    final mileageSoon =
        dueMileage != null &&
        currentMileage != null &&
        dueMileage! <= currentMileage + 1500;
    return dateSoon || mileageSoon;
  }
}

class VehicleDocumentSuggestion {
  const VehicleDocumentSuggestion({
    required this.id,
    required this.documentId,
    required this.suggestionType,
    required this.title,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.confidence,
  });

  final String id;
  final String documentId;
  final String suggestionType;
  final String title;
  final Map<String, dynamic> payload;
  final String status;
  final DateTime createdAt;
  final double? confidence;

  factory VehicleDocumentSuggestion.fromMap(Map<String, dynamic> map) {
    return VehicleDocumentSuggestion(
      id: _text(map['id']),
      documentId: _text(map['document_id']),
      suggestionType: _text(map['suggestion_type'], fallback: 'EVENT'),
      title: _text(map['title'], fallback: 'Information détectée'),
      payload: _map(map['payload']),
      status: _text(map['status'], fallback: 'PENDING'),
      createdAt: _dateTime(map['created_at']) ?? DateTime.now(),
      confidence: _nullableDecimal(map['confidence']),
    );
  }

  String get typeLabel => switch (suggestionType) {
    'ODOMETER' => 'Kilométrage',
    'EXPENSE' => 'Dépense',
    'MAINTENANCE' => 'Entretien',
    'WARRANTY' => 'Garantie',
    'ADVICE' => 'Conseil',
    _ => 'Événement',
  };
}

class VehicleCareBundle {
  const VehicleCareBundle({
    required this.dashboard,
    required this.schedules,
    required this.suggestions,
    required this.completedDocumentCount,
  });

  final VehicleCareDashboard dashboard;
  final List<VehicleMaintenanceSchedule> schedules;
  final List<VehicleDocumentSuggestion> suggestions;
  final int completedDocumentCount;
}

String eventTypeLabel(String value) => switch (value) {
  'PURCHASE' => 'Achat',
  'SALE' => 'Vente',
  'MAINTENANCE' => 'Entretien',
  'REPAIR' => 'Réparation',
  'INSPECTION' => 'Contrôle technique',
  'REINSPECTION' => 'Contre-visite',
  'TYRES' => 'Pneus',
  'ODOMETER' => 'Kilométrage',
  'FUEL' => 'Carburant',
  'CHARGING' => 'Recharge',
  'INSURANCE' => 'Assurance',
  'WARRANTY' => 'Garantie',
  'ACCIDENT' => 'Sinistre',
  'RECALL' => 'Rappel constructeur',
  'EQUIPMENT' => 'Équipement',
  'CONDITION' => 'État du véhicule',
  'ADMINISTRATIVE' => 'Administratif',
  _ => 'Autre',
};

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _integer(dynamic value) => _nullableInteger(value) ?? 0;

int? _nullableInteger(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _decimal(dynamic value) => _nullableDecimal(value) ?? 0;

double? _nullableDecimal(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}

DateTime? _dateTime(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
