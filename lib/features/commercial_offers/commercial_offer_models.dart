class CommercialOfferBundle {
  const CommercialOfferBundle({
    required this.vehicleId,
    required this.vehicleName,
    required this.offers,
    required this.generatedAt,
    required this.activeSourceCount,
    required this.activeOfferCount,
    this.lastSuccessfulSyncAt,
  });

  final String vehicleId;
  final String vehicleName;
  final List<CommercialOffer> offers;
  final DateTime generatedAt;
  final int activeSourceCount;
  final int activeOfferCount;
  final DateTime? lastSuccessfulSyncAt;

  CommercialOffer? get topOffer => offers.isEmpty ? null : offers.first;

  int get relevantNowCount => offers.where((offer) => offer.relevantNow).length;

  int get savedCount => offers.where((offer) => offer.isSaved).length;

  int get currentVehicleCount =>
      offers.where((offer) => !offer.isPurchaseOffer).length;

  int get purchaseCount =>
      offers.where((offer) => offer.isPurchaseOffer).length;

  int relevantNowCountForContext(String context) => offers
      .where((offer) => offer.offerContext == context && offer.relevantNow)
      .length;

  factory CommercialOfferBundle.fromMap(Map<String, dynamic> map) {
    final rawOffers = map['offers'];

    return CommercialOfferBundle(
      vehicleId: map['vehicle_id']?.toString() ?? '',
      vehicleName: map['vehicle_name']?.toString() ?? 'Mon véhicule',
      offers: rawOffers is List
          ? rawOffers
                .whereType<Map>()
                .map(
                  (row) =>
                      CommercialOffer.fromMap(Map<String, dynamic>.from(row)),
                )
                .toList(growable: false)
          : const [],
      generatedAt:
          DateTime.tryParse(map['generated_at']?.toString() ?? '') ??
          DateTime.now(),
      activeSourceCount: _integer(map['active_source_count']),
      activeOfferCount: _integer(map['active_offer_count']),
      lastSuccessfulSyncAt: DateTime.tryParse(
        map['last_successful_sync_at']?.toString() ?? '',
      ),
    );
  }
}

class CommercialOffer {
  const CommercialOffer({
    required this.id,
    required this.offerKey,
    required this.title,
    required this.summary,
    required this.category,
    required this.offerContext,
    required this.targetingScope,
    required this.benefitKind,
    required this.benefitLabel,
    required this.currency,
    required this.sourceName,
    required this.officialUrl,
    required this.conditionsSummary,
    required this.eligibilityNotes,
    required this.compatibility,
    required this.relevanceLabel,
    required this.relevanceScore,
    required this.relevantNow,
    required this.expiresSoon,
    required this.isSaved,
    required this.why,
    required this.requiresManualEligibility,
    required this.requiresNetworkParticipation,
    required this.requiresExistingContract,
    required this.lastVerifiedAt,
    required this.autoExtracted,
    this.extractionConfidence,
    this.benefitValue,
    this.priceAmount,
    this.originalPriceAmount,
    this.startsAt,
    this.endsAt,
    this.brands = const [],
    this.modelPatterns = const [],
    this.fuelTypes = const [],
    this.commercialValueScore = 0,
  });

  final String id;
  final String offerKey;
  final String title;
  final String summary;
  final String category;
  final String offerContext;
  final String targetingScope;
  final String benefitKind;
  final String benefitLabel;
  final double? benefitValue;
  final double? priceAmount;
  final double? originalPriceAmount;
  final String currency;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String sourceName;
  final String officialUrl;
  final String conditionsSummary;
  final String eligibilityNotes;
  final String compatibility;
  final String relevanceLabel;
  final int relevanceScore;
  final bool relevantNow;
  final bool expiresSoon;
  final bool isSaved;
  final List<String> why;
  final bool requiresManualEligibility;
  final bool requiresNetworkParticipation;
  final bool requiresExistingContract;
  final DateTime lastVerifiedAt;
  final bool autoExtracted;
  final int? extractionConfidence;
  final List<String> brands;
  final List<String> modelPatterns;
  final List<String> fuelTypes;
  final int commercialValueScore;

  bool get isPurchaseOffer => offerContext == 'VEHICLE_PURCHASE';

  String get contextLabel => switch (offerContext) {
    'VEHICLE_PURCHASE' => 'Changer de voiture',
    'FINANCE_INSURANCE' => 'Financement et protection',
    _ => 'Pour ma voiture',
  };

  String get categoryLabel => switch (category) {
    'MAINTENANCE' => 'Entretien',
    'TYRES' => 'Pneumatiques',
    'BATTERY' => 'Batterie',
    'CLIMATE' => 'Climatisation',
    'ACCESSORIES' => 'Accessoires',
    'INSPECTION' => 'Contrôle technique',
    'WINDSCREEN' => 'Pare-brise',
    'CONTRACT' => 'Contrat d’entretien',
    'BODYWORK' => 'Carrosserie',
    'PARTS' => 'Pièces',
    'NEW_VEHICLE' => 'Véhicule neuf',
    'USED_VEHICLE' => 'Véhicule d’occasion',
    'FINANCE' => 'Financement',
    'INSURANCE' => 'Assurance',
    'ASSISTANCE' => 'Assistance',
    _ => 'Service automobile',
  };

  String get compatibilityLabel {
    if (isPurchaseOffer) {
      return switch (compatibility) {
        'COMPATIBLE' => 'Même modèle identifié',
        'LIKELY' => 'Même modèle probablement identifié',
        _ => 'Conditions commerciales à vérifier',
      };
    }

    return switch (compatibility) {
      'COMPATIBLE' => 'Compatible avec votre véhicule',
      'LIKELY' => 'Probablement compatible',
      _ => 'Conditions à vérifier',
    };
  }

  List<String> get purchaseBadgeLabels {
    final values = <String>[categoryLabel];
    if (brands.isNotEmpty && brands.first.trim().isNotEmpty) {
      values.add(brands.first.trim());
    }
    if (modelPatterns.isNotEmpty) {
      final cleaned = modelPatterns.first
          .replaceAll('*', ' ')
          .replaceAll('.', ' ')
          .replaceAll('?', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty) {
        values.add(cleaned);
      }
    }
    if (fuelTypes.isNotEmpty) {
      final fuel = switch (fuelTypes.first.toLowerCase()) {
        'petrol' => 'Essence',
        'diesel' => 'Diesel',
        'hybrid' => 'Hybride',
        'plug_in_hybrid' => 'Hybride rechargeable',
        'electric' => 'Électrique',
        _ => fuelTypes.first.trim(),
      };
      if (fuel.isNotEmpty) {
        values.add(fuel);
      }
    }
    return values.toSet().take(4).toList(growable: false);
  }

  String get clearBenefitLabel {
    final saving = calculatedSavings;
    if (saving != null && saving > 0) {
      return '${_money(saving)} € de remise';
    }
    final value = benefitValue;
    final kind = benefitKind.toUpperCase();
    if (value != null && value > 0 && kind.contains('PERCENT')) {
      return '${_money(value)} % de remise';
    }
    if (value != null &&
        value > 0 &&
        (kind.contains('DISCOUNT') ||
            kind.contains('AMOUNT') ||
            kind == 'FIXED')) {
      return '${_money(value)} € de remise';
    }
    return benefitLabel.trim().isEmpty ? priceLabel : benefitLabel.trim();
  }

  String get conditionsPreview {
    if (conditionsSummary.trim().isNotEmpty) {
      return conditionsSummary.trim();
    }
    if (eligibilityNotes.trim().isNotEmpty) {
      return eligibilityNotes.trim();
    }
    return summary.trim();
  }

  String get validityLabel {
    final end = endsAt;
    if (end == null) return 'Offre suivie sans date de fin publiée';
    return 'Valable jusqu’au ${_date(end)}';
  }

  String get verificationLabel {
    final now = DateTime.now();
    final local = lastVerifiedAt.toLocal();
    final days = now.difference(local).inDays;

    if (days <= 0) return 'Source officielle vérifiée aujourd’hui';
    if (days == 1) return 'Source officielle vérifiée hier';
    return 'Source officielle vérifiée il y a $days jours';
  }

  String get priceLabel {
    final price = priceAmount;
    if (price != null) {
      return '${_money(price)} $currency';
    }
    return benefitLabel;
  }

  double? get calculatedSavings {
    final original = originalPriceAmount;
    final current = priceAmount;
    if (original == null || current == null || original <= current) {
      return null;
    }
    return original - current;
  }

  factory CommercialOffer.fromMap(Map<String, dynamic> map) {
    final rawWhy = map['why'];

    return CommercialOffer(
      id: map['id']?.toString() ?? '',
      offerKey: map['offer_key']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Offre officielle',
      summary: map['summary']?.toString() ?? '',
      category: map['category']?.toString() ?? 'OTHER',
      offerContext: map['offer_context']?.toString() ?? 'CURRENT_VEHICLE',
      targetingScope: map['targeting_scope']?.toString() ?? 'UNKNOWN',
      benefitKind: map['benefit_kind']?.toString() ?? 'INFO',
      benefitLabel: map['benefit_label']?.toString() ?? 'Avantage à vérifier',
      benefitValue: _nullableDecimal(map['benefit_value']),
      priceAmount: _nullableDecimal(map['price_amount']),
      originalPriceAmount: _nullableDecimal(map['original_price_amount']),
      brands: _stringList(map['brands']),
      modelPatterns: _stringList(map['model_patterns']),
      fuelTypes: _stringList(map['fuel_types']),
      commercialValueScore: _integer(map['commercial_value_score']),
      currency: map['currency']?.toString() ?? 'EUR',
      startsAt: _dateTime(map['starts_at']),
      endsAt: _dateTime(map['ends_at']),
      sourceName: map['source_name']?.toString() ?? 'Source officielle',
      officialUrl: map['official_url']?.toString() ?? '',
      conditionsSummary: map['conditions_summary']?.toString() ?? '',
      eligibilityNotes: map['eligibility_notes']?.toString() ?? '',
      compatibility: map['compatibility']?.toString() ?? 'CHECK',
      relevanceLabel: map['relevance_label']?.toString() ?? 'À vérifier',
      relevanceScore: _integer(map['relevance_score']),
      relevantNow: map['relevant_now'] == true,
      expiresSoon: map['expires_soon'] == true,
      isSaved: map['is_saved'] == true,
      why: rawWhy is List
          ? rawWhy
                .map((value) => value?.toString().trim() ?? '')
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const [],
      requiresManualEligibility: map['requires_manual_eligibility'] == true,
      requiresNetworkParticipation:
          map['requires_network_participation'] == true,
      requiresExistingContract: map['requires_existing_contract'] == true,
      lastVerifiedAt:
          DateTime.tryParse(map['last_verified_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      autoExtracted: map['auto_extracted'] == true,
      extractionConfidence: map['extraction_confidence'] == null
          ? null
          : _integer(map['extraction_confidence']),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDecimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _dateTime(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : DateTime.tryParse(text);
}

String _date(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _money(double value) {
  final fixed = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return fixed.replaceAll('.', ',');
}
