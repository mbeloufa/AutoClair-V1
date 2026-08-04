class Vehicle360Precheck {
  const Vehicle360Precheck({
    required this.vehicleId,
    required this.dataQuality,
    required this.marketData,
    required this.saleTiming,
    this.latestReport,
  });

  final String vehicleId;
  final Vehicle360DataQuality dataQuality;
  final Vehicle360MarketData marketData;
  final Vehicle360SaleTiming saleTiming;
  final Vehicle360Report? latestReport;

  factory Vehicle360Precheck.fromMap(Map<String, dynamic> map) {
    return Vehicle360Precheck(
      vehicleId: _text(map['vehicle_id']),
      dataQuality: Vehicle360DataQuality.fromMap(_map(map['data_quality'])),
      marketData: Vehicle360MarketData.fromMap(_map(map['market_data'])),
      saleTiming: Vehicle360SaleTiming.fromMap(_map(map['timing'])),
      latestReport: Vehicle360Report.tryFromEnvelope(map['latest_report']),
    );
  }
}

class Vehicle360DataQuality {
  const Vehicle360DataQuality({
    required this.score,
    required this.canGenerate,
    required this.missing,
    required this.warnings,
    required this.counts,
    required this.brand,
    required this.model,
    required this.year,
    required this.energy,
    required this.mileage,
  });

  final int score;
  final bool canGenerate;
  final List<String> missing;
  final List<String> warnings;
  final Map<String, int> counts;
  final String? brand;
  final String? model;
  final String? year;
  final String? energy;
  final int? mileage;

  factory Vehicle360DataQuality.fromMap(Map<String, dynamic> map) {
    final detected = _map(map['detected']);
    final rawCounts = _map(map['counts']);
    return Vehicle360DataQuality(
      score: _integer(map['score']),
      canGenerate: map['can_generate'] == true,
      missing: _strings(map['missing']),
      warnings: _strings(map['warnings']),
      counts: rawCounts.map((key, value) => MapEntry(key, _integer(value))),
      brand: _nullableText(detected['brand']),
      model: _nullableText(detected['model']),
      year: _nullableText(detected['year']),
      energy: _nullableText(detected['energy']),
      mileage: _nullableInteger(detected['mileage']),
    );
  }

  int get eventCount =>
      (counts['vehicle_events'] ?? 0) +
      (counts['vehicle_maintenance_schedules'] ?? 0);

  int get documentCount =>
      (counts['vehicle_document_suggestions'] ?? 0) +
      (counts['documents'] ?? 0);

  int get expenseCount => counts['vehicle_expenses'] ?? 0;

  int get recallCount => counts['vehicle_recall_matches'] ?? 0;

  String get levelLabel {
    if (score >= 80) return 'Dossier très complet';
    if (score >= 65) return 'Dossier exploitable';
    if (score >= 40) return 'Dossier à compléter';
    return 'Informations insuffisantes';
  }
}

class Vehicle360ExecutiveSummary {
  const Vehicle360ExecutiveSummary({
    required this.title,
    required this.overallStatus,
    required this.summary,
    required this.confidence,
  });

  final String title;
  final String overallStatus;
  final String summary;
  final String confidence;

  factory Vehicle360ExecutiveSummary.fromMap(Map<String, dynamic> map) {
    return Vehicle360ExecutiveSummary(
      title: _text(map['title'], fallback: 'Bilan AutoClair 360'),
      overallStatus: _text(
        map['overall_status'],
        fallback: 'insufficient_data',
      ),
      summary: _text(
        map['summary'],
        fallback: "Le bilan ne contient pas encore de synthèse.",
      ),
      confidence: _text(map['confidence'], fallback: 'low'),
    );
  }

  String get statusLabel => switch (overallStatus) {
    'good' => 'Situation satisfaisante',
    'monitor' => 'Points à surveiller',
    'plan' => 'Actions à programmer',
    'urgent' => 'Action rapide recommandée',
    _ => 'Données à compléter',
  };
}

class Vehicle360Finding {
  const Vehicle360Finding({
    required this.id,
    required this.title,
    required this.explanation,
    required this.action,
    required this.priority,
    required this.confidence,
    required this.sourceIds,
  });

  final String id;
  final String title;
  final String explanation;
  final String action;
  final String priority;
  final String confidence;
  final List<String> sourceIds;

  factory Vehicle360Finding.fromMap(Map<String, dynamic> map) {
    return Vehicle360Finding(
      id: _text(map['id']),
      title: _text(map['title'], fallback: 'Point relevé'),
      explanation: _text(map['explanation']),
      action: _text(map['action']),
      priority: _text(map['priority'], fallback: 'information'),
      confidence: _text(map['confidence'], fallback: 'low'),
      sourceIds: _strings(map['source_ids']),
    );
  }

  String get priorityLabel => switch (priority) {
    'urgent' => 'À traiter rapidement',
    'plan' => 'À programmer',
    'monitor' => 'À surveiller',
    _ => 'Information',
  };

  String get confidenceLabel => _confidenceLabel(confidence);
}

class Vehicle360Advice {
  const Vehicle360Advice({
    required this.id,
    required this.title,
    required this.explanation,
    required this.action,
    required this.confidence,
    required this.sourceIds,
  });

  final String id;
  final String title;
  final String explanation;
  final String action;
  final String confidence;
  final List<String> sourceIds;

  factory Vehicle360Advice.fromMap(Map<String, dynamic> map) {
    return Vehicle360Advice(
      id: _text(map['id']),
      title: _text(map['title'], fallback: 'Conseil AutoClair'),
      explanation: _text(map['explanation']),
      action: _text(map['action']),
      confidence: _text(map['confidence'], fallback: 'low'),
      sourceIds: _strings(map['source_ids']),
    );
  }

  String get confidenceLabel => _confidenceLabel(confidence);
}

class Vehicle360MaintenanceAnalysis {
  const Vehicle360MaintenanceAnalysis({
    required this.positiveFindings,
    required this.attentionFindings,
    required this.urgentFindings,
    required this.next12MonthActions,
  });

  final List<Vehicle360Finding> positiveFindings;
  final List<Vehicle360Finding> attentionFindings;
  final List<Vehicle360Finding> urgentFindings;
  final List<Vehicle360Finding> next12MonthActions;

  factory Vehicle360MaintenanceAnalysis.fromMap(Map<String, dynamic> map) {
    return Vehicle360MaintenanceAnalysis(
      positiveFindings: _maps(
        map['positive_findings'],
      ).map(Vehicle360Finding.fromMap).toList(growable: false),
      attentionFindings: _maps(
        map['attention_findings'],
      ).map(Vehicle360Finding.fromMap).toList(growable: false),
      urgentFindings: _maps(
        map['urgent_findings'],
      ).map(Vehicle360Finding.fromMap).toList(growable: false),
      next12MonthActions: _maps(
        map['next_12_month_actions'],
      ).map(Vehicle360Finding.fromMap).toList(growable: false),
    );
  }
}

class VehicleMarketValuation {
  const VehicleMarketValuation({
    required this.valuationDate,
    required this.provider,
    required this.valuationType,
    required this.valueLow,
    required this.valueMid,
    required this.valueHigh,
    required this.confidenceScore,
  });

  final DateTime valuationDate;
  final String provider;
  final String valuationType;
  final double? valueLow;
  final double valueMid;
  final double? valueHigh;
  final double? confidenceScore;

  factory VehicleMarketValuation.fromMap(Map<String, dynamic> map) {
    return VehicleMarketValuation(
      valuationDate:
          _dateTime(map['valuation_date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      provider: _text(map['provider'], fallback: 'Source de marché'),
      valuationType: _text(map['valuation_type'], fallback: 'market'),
      valueLow: _nullableDecimal(map['value_low_eur']),
      valueMid: _decimal(map['value_mid_eur']),
      valueHigh: _nullableDecimal(map['value_high_eur']),
      confidenceScore: _nullableDecimal(map['confidence_score']),
    );
  }

  String get typeLabel => switch (valuationType) {
    'private_sale' => 'Vente entre particuliers',
    'professional_retail' => 'Prix professionnel affiché',
    'trade_in' => 'Reprise professionnelle',
    'b2b' => 'Valeur professionnelle',
    _ => 'Valeur de marché',
  };
}

class VehicleValueForecast {
  const VehicleValueForecast({
    required this.forecastDate,
    required this.horizonMonths,
    required this.scenario,
    required this.value,
    required this.method,
    required this.confidenceScore,
  });

  final DateTime forecastDate;
  final int horizonMonths;
  final String scenario;
  final double value;
  final String method;
  final double? confidenceScore;

  factory VehicleValueForecast.fromMap(Map<String, dynamic> map) {
    return VehicleValueForecast(
      forecastDate:
          _dateTime(map['forecast_date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      horizonMonths: _integer(map['horizon_months']),
      scenario: _text(map['scenario'], fallback: 'central'),
      value: _decimal(map['value_eur']),
      method: _text(map['method']),
      confidenceScore: _nullableDecimal(map['confidence_score']),
    );
  }
}

class Vehicle360MarketData {
  const Vehicle360MarketData({
    required this.available,
    required this.history,
    required this.forecasts,
    required this.freshnessDays,
    required this.disclaimer,
    this.privateSale,
    this.tradeIn,
  });

  final bool available;
  final VehicleMarketValuation? privateSale;
  final VehicleMarketValuation? tradeIn;
  final List<VehicleMarketValuation> history;
  final List<VehicleValueForecast> forecasts;
  final int? freshnessDays;
  final String disclaimer;

  factory Vehicle360MarketData.fromMap(Map<String, dynamic> map) {
    final privateMap = _nullableMap(map['private_sale']);
    final tradeMap = _nullableMap(map['trade_in']);
    final history =
        _maps(map['history'])
            .where((item) => _decimal(item['value_mid_eur']) > 0)
            .map(VehicleMarketValuation.fromMap)
            .toList(growable: false)
          ..sort(
            (left, right) => left.valuationDate.compareTo(right.valuationDate),
          );
    final forecasts =
        _maps(map['forecasts'])
            .where((item) => _decimal(item['value_eur']) > 0)
            .map(VehicleValueForecast.fromMap)
            .toList(growable: false)
          ..sort(
            (left, right) => left.forecastDate.compareTo(right.forecastDate),
          );

    return Vehicle360MarketData(
      available: map['available'] == true,
      privateSale: privateMap == null
          ? null
          : VehicleMarketValuation.fromMap(privateMap),
      tradeIn: tradeMap == null
          ? null
          : VehicleMarketValuation.fromMap(tradeMap),
      history: history,
      forecasts: forecasts,
      freshnessDays: _nullableInteger(map['freshness_days']),
      disclaimer: _text(
        map['disclaimer'],
        fallback: "Estimation de marché et non prix de vente garanti.",
      ),
    );
  }

  VehicleValueForecast? get central12MonthForecast {
    for (final item in forecasts) {
      if (item.scenario == 'central' && item.horizonMonths == 12) {
        return item;
      }
    }
    return null;
  }

  double? get projectedDepreciationAmount {
    final current = privateSale?.valueMid;
    final future = central12MonthForecast?.value;
    if (current == null || future == null) return null;
    return current - future;
  }

  double? get projectedDepreciationRate {
    final current = privateSale?.valueMid;
    final amount = projectedDepreciationAmount;
    if (current == null || current <= 0 || amount == null) return null;
    return amount / current;
  }

  String get freshnessLabel {
    final days = freshnessDays;
    if (days == null) return 'Date de cote inconnue';
    if (days <= 0) return "Mise à jour aujourd'hui";
    if (days == 1) return 'Mise à jour hier';
    return 'Mise à jour il y a $days jours';
  }
}

class Vehicle360SaleTiming {
  const Vehicle360SaleTiming({
    required this.status,
    required this.score,
    required this.reasons,
    required this.projectedDepreciationRate,
  });

  final String status;
  final int score;
  final List<String> reasons;
  final double? projectedDepreciationRate;

  factory Vehicle360SaleTiming.fromMap(Map<String, dynamic> map) {
    return Vehicle360SaleTiming(
      status: _text(map['status'], fallback: 'data_insufficient'),
      score: _integer(map['score']),
      reasons: _strings(map['reasons']),
      projectedDepreciationRate: _nullableDecimal(
        map['projected_12_month_depreciation_rate'],
      ),
    );
  }

  String get statusLabel => switch (status) {
    'compare_now' => 'Comparer une vente maintenant',
    'prepare_then_sell' => 'Préparer la vente',
    'monitor' => 'Conserver et surveiller',
    _ => 'Données insuffisantes',
  };

  String get shortLabel => switch (status) {
    'compare_now' => 'Comparer maintenant',
    'prepare_then_sell' => 'Préparer',
    'monitor' => 'Surveiller',
    _ => 'À compléter',
  };
}

class VehicleSaleScenario {
  const VehicleSaleScenario({
    required this.code,
    required this.expectedSaleValue,
    required this.requiredCosts,
    required this.holdingCosts,
    required this.expectedNetValue,
    required this.estimatedDelayDays,
    required this.confidenceScore,
    required this.explanation,
    required this.details,
  });

  final String code;
  final double? expectedSaleValue;
  final double? requiredCosts;
  final double? holdingCosts;
  final double? expectedNetValue;
  final int? estimatedDelayDays;
  final double? confidenceScore;
  final String explanation;
  final Map<String, dynamic> details;

  factory VehicleSaleScenario.fromMap(Map<String, dynamic> map) {
    return VehicleSaleScenario(
      code: _text(map['scenario_code']),
      expectedSaleValue: _nullableDecimal(map['expected_sale_value_eur']),
      requiredCosts: _nullableDecimal(map['required_costs_eur']),
      holdingCosts: _nullableDecimal(map['holding_costs_eur']),
      expectedNetValue: _nullableDecimal(map['expected_net_value_eur']),
      estimatedDelayDays: _nullableInteger(map['estimated_delay_days']),
      confidenceScore: _nullableDecimal(map['confidence_score']),
      explanation: _text(map['explanation']),
      details: _map(map['details']),
    );
  }

  String get title => switch (code) {
    'sell_private_now' => 'Vendre à un particulier maintenant',
    'trade_in_now' => 'Choisir une reprise professionnelle',
    'prepare_then_sell' => 'Préparer puis vendre',
    'keep_12_months' => 'Conserver encore douze mois',
    _ => 'Scénario de vente',
  };

  String get compactTitle => switch (code) {
    'sell_private_now' => 'Particulier',
    'trade_in_now' => 'Reprise',
    'prepare_then_sell' => 'Préparation',
    'keep_12_months' => 'Conservation',
    _ => 'Scénario',
  };
}

class Vehicle360SaleAnalysis {
  const Vehicle360SaleAnalysis({
    required this.summary,
    required this.reasons,
    required this.preparationActions,
    required this.negotiationPoints,
    required this.timing,
  });

  final String summary;
  final List<String> reasons;
  final List<Vehicle360Advice> preparationActions;
  final List<Vehicle360Advice> negotiationPoints;
  final Vehicle360SaleTiming timing;

  factory Vehicle360SaleAnalysis.fromMap(Map<String, dynamic> map) {
    return Vehicle360SaleAnalysis(
      summary: _text(
        map['summary'],
        fallback: "La recommandation de vente n'est pas encore disponible.",
      ),
      reasons: _strings(map['reasons']),
      preparationActions: _maps(
        map['preparation_actions'],
      ).map(Vehicle360Advice.fromMap).toList(growable: false),
      negotiationPoints: _maps(
        map['negotiation_points'],
      ).map(Vehicle360Advice.fromMap).toList(growable: false),
      timing: Vehicle360SaleTiming.fromMap(_map(map['timing'])),
    );
  }
}

class Vehicle360Source {
  const Vehicle360Source({
    required this.sourceId,
    required this.sourceType,
    required this.label,
    required this.confidence,
    this.sourceDate,
  });

  final String sourceId;
  final String sourceType;
  final String label;
  final DateTime? sourceDate;
  final String confidence;

  factory Vehicle360Source.fromMap(Map<String, dynamic> map) {
    return Vehicle360Source(
      sourceId: _text(map['source_id']),
      sourceType: _text(map['source_type']),
      label: _text(map['source_label'], fallback: 'Source AutoClair'),
      sourceDate: _dateTime(map['source_date']),
      confidence: _text(map['confidence_level'], fallback: 'low'),
    );
  }

  String get typeLabel {
    if (sourceType == 'vehicle') return 'Fiche véhicule';
    if (sourceType.contains('event')) return 'Carnet';
    if (sourceType.contains('document')) return 'Document';
    if (sourceType.contains('valuation')) return 'Cote de marché';
    if (sourceType.contains('recall')) return 'Rappel constructeur';
    if (sourceType.contains('risk')) return 'Point de vigilance';
    if (sourceType.contains('expense')) return 'Dépense';
    if (sourceType.contains('schedule')) return 'Échéance';
    return 'Donnée AutoClair';
  }

  String get confidenceLabel => _confidenceLabel(confidence);
}

class Vehicle360Report {
  const Vehicle360Report({
    required this.id,
    required this.vehicleId,
    required this.status,
    required this.requestedAt,
    required this.completedAt,
    required this.dataQualityScore,
    required this.overallConfidenceScore,
    required this.executiveSummary,
    required this.dataQuality,
    required this.maintenance,
    required this.usageAdvice,
    required this.saleAnalysis,
    required this.marketData,
    required this.scenarios,
    required this.questionsForProfessional,
    required this.limitations,
    required this.sources,
    required this.aiModel,
    required this.generatedAt,
  });

  final String id;
  final String vehicleId;
  final String status;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final int dataQualityScore;
  final int overallConfidenceScore;
  final Vehicle360ExecutiveSummary executiveSummary;
  final Vehicle360DataQuality dataQuality;
  final Vehicle360MaintenanceAnalysis maintenance;
  final List<Vehicle360Advice> usageAdvice;
  final Vehicle360SaleAnalysis saleAnalysis;
  final Vehicle360MarketData marketData;
  final List<VehicleSaleScenario> scenarios;
  final List<String> questionsForProfessional;
  final List<String> limitations;
  final List<Vehicle360Source> sources;
  final String? aiModel;
  final DateTime? generatedAt;

  static Vehicle360Report? tryFromEnvelope(dynamic value) {
    final envelope = _nullableMap(value);
    if (envelope == null || _nullableMap(envelope['report']) == null) {
      return null;
    }
    return Vehicle360Report.fromEnvelope(envelope);
  }

  factory Vehicle360Report.fromEnvelope(Map<String, dynamic> envelope) {
    final report = _map(envelope['report']);
    final result = _map(report['result_json']);
    final sale = _map(result['sale_analysis']);
    final generation = _map(result['generation']);
    final rawScenarioRows = _maps(envelope['scenarios']);
    final nestedScenarioRows = _maps(sale['scenarios']);
    final scenarioRows = rawScenarioRows.isNotEmpty
        ? rawScenarioRows
        : nestedScenarioRows;

    return Vehicle360Report(
      id: _text(report['id']),
      vehicleId: _text(report['vehicle_id']),
      status: _text(report['status'], fallback: 'completed'),
      requestedAt: _dateTime(report['requested_at']),
      completedAt: _dateTime(report['completed_at']),
      dataQualityScore: _integer(report['data_quality_score']),
      overallConfidenceScore: _integer(report['overall_confidence_score']),
      executiveSummary: Vehicle360ExecutiveSummary.fromMap(
        _map(result['executive_summary']),
      ),
      dataQuality: Vehicle360DataQuality.fromMap(_map(result['data_quality'])),
      maintenance: Vehicle360MaintenanceAnalysis.fromMap(
        _map(result['maintenance']),
      ),
      usageAdvice: _maps(
        result['usage_advice'],
      ).map(Vehicle360Advice.fromMap).toList(growable: false),
      saleAnalysis: Vehicle360SaleAnalysis.fromMap(sale),
      marketData: Vehicle360MarketData.fromMap(_map(result['market_data'])),
      scenarios: scenarioRows
          .map(VehicleSaleScenario.fromMap)
          .toList(growable: false),
      questionsForProfessional: _strings(result['questions_for_professional']),
      limitations: _strings(result['limitations']),
      sources: _maps(
        envelope['sources'],
      ).map(Vehicle360Source.fromMap).toList(growable: false),
      aiModel: _nullableText(generation['ai_model'] ?? report['ai_model']),
      generatedAt: _dateTime(generation['generated_at']),
    );
  }

  String get generatedLabel {
    final date = completedAt ?? generatedAt;
    if (date == null) return 'Date inconnue';
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
  }

  int get actionCount =>
      maintenance.urgentFindings.length +
      maintenance.attentionFindings.length +
      maintenance.next12MonthActions.length;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic>? _nullableMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _strings(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
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

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInteger(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

double _decimal(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

double? _nullableDecimal(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

DateTime? _dateTime(dynamic value) {
  final text = _nullableText(value);
  return text == null ? null : DateTime.tryParse(text)?.toLocal();
}

String _confidenceLabel(String confidence) => switch (confidence) {
  'high' => 'élevée',
  'medium' => 'moyenne',
  _ => 'limitée',
};

String _twoDigits(int value) => value.toString().padLeft(2, '0');
