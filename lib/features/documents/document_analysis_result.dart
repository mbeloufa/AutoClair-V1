import '../vehicle_care/vehicle_event_catalog.dart';
import 'document_type_catalog.dart';

class DetectedVehicleOperation {
  const DetectedVehicleOperation({
    required this.categoryCode,
    required this.categoryLabel,
    required this.subcategoryCode,
    required this.subcategoryLabel,
    required this.title,
    this.mileage,
    this.amount,
    this.currency = 'EUR',
    this.providerName,
    this.documentDate,
  });

  final String categoryCode;
  final String categoryLabel;
  final String subcategoryCode;
  final String subcategoryLabel;
  final String title;
  final int? mileage;
  final double? amount;
  final String currency;
  final String? providerName;
  final String? documentDate;

  String get heading => 'Opération détectée';

  String get categoryPath => '$categoryLabel • $subcategoryLabel';
}

class DocumentAnalysisResult {
  const DocumentAnalysisResult({
    required this.id,
    required this.documentId,
    required this.summary,
    required this.overallConfidence,
    required this.resultJson,
    this.declaredDocumentType,
  });

  final String id;
  final String documentId;
  final String summary;
  final double overallConfidence;
  final Map<String, dynamic> resultJson;
  final String? declaredDocumentType;

  factory DocumentAnalysisResult.fromMap(Map<String, dynamic> map) {
    final rawResult = map['result_json'];
    final sanitized = rawResult is Map
        ? _sanitizeMap(Map<String, dynamic>.from(rawResult))
        : <String, dynamic>{};

    return DocumentAnalysisResult(
      id: map['id']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      summary: _sanitizeSummary(map['summary']?.toString() ?? ''),
      overallConfidence: _asDouble(map['overall_confidence']) ?? 0,
      resultJson: sanitized,
      declaredDocumentType: _nullableString(
        map['declared_document_type'] ?? map['document_type'],
      ),
    );
  }

  String get confidenceLabel => '${(overallConfidence * 100).round()} %';

  String get effectiveDocumentType {
    if (declaredDocumentType == 'technical_inspection_report') {
      return 'technical_inspection_report';
    }

    final detectedType = resultJson['document_type_detected']?.toString();
    if (DocumentTypeCatalog.isKnown(detectedType) && detectedType != 'other') {
      return detectedType!;
    }

    if (DocumentTypeCatalog.isSelectable(declaredDocumentType)) {
      return declaredDocumentType!;
    }

    return 'unknown';
  }

  String get detectedTypeLabel {
    return DocumentTypeCatalog.labelFor(
      effectiveDocumentType,
      fallback: 'Type non déterminé',
    );
  }

  bool get isTechnicalInspection =>
      effectiveDocumentType == 'technical_inspection_report';

  bool get isContractDocument => const <String>{
    'purchase_order',
    'sale_contract',
    'lease_contract',
    'loa_contract',
    'lld_contract',
    'insurance_contract',
  }.contains(effectiveDocumentType);

  bool get supportsCarnetSync => !isContractDocument;

  Map<String, dynamic> get contractAnalysis => objectAt('contract_analysis');

  String? get contractCommitmentSummary =>
      _nullableString(contractAnalysis['commitment_summary']);

  List<Map<String, dynamic>> get contractObligations =>
      _mapList(contractAnalysis['obligations']);

  List<Map<String, dynamic>> get contractCosts =>
      _mapList(contractAnalysis['costs']);

  List<Map<String, dynamic>> get contractImportantClauses =>
      _mapList(contractAnalysis['important_clauses']);

  List<String> get contractMissingInformation {
    final value = contractAnalysis['missing_information'];
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> get technicalInspection =>
      objectAt('technical_inspection');

  List<Map<String, dynamic>> get technicalInspectionDefects =>
      technicalInspection['defects'] is List
      ? (technicalInspection['defects'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
      : const [];

  String get technicalInspectionResultLabel {
    return switch (technicalInspection['result']?.toString()) {
      'favorable' => 'Favorable',
      'unfavorable_major' => 'Défavorable — défaillances majeures',
      'unfavorable_critical' => 'Défavorable — défaillances critiques',
      _ => 'Résultat à vérifier',
    };
  }

  bool? get technicalInspectionRequiresReinspection {
    final value = technicalInspection['reinspection_required'];
    return value is bool ? value : null;
  }

  String? get technicalInspectionReinspectionDeadline =>
      _nullableString(technicalInspection['reinspection_deadline']);

  String get readabilityLabel {
    final quality = objectAt('document_quality');
    return switch (quality['readability']?.toString()) {
      'good' => 'Bonne',
      'partial' => 'Partielle',
      'poor' => 'Faible',
      _ => 'Non déterminée',
    };
  }

  DetectedVehicleOperation get detectedOperation {
    final items = objectListAt('line_items');
    final descriptions = items
        .map((item) => _nullableString(item['description']))
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final declaredText = [
      detectedTypeLabel,
      ...descriptions,
      stringAt('operation_detected') ?? '',
    ].join(' ');

    final fallbackType = switch (declaredDocumentType) {
      'technical_inspection_report' => 'INSPECTION',
      _ => null,
    };
    final classification = VehicleEventCatalog.classify(
      declaredText,
      fallbackEventType: fallbackType,
    );

    final matchingDescriptions = descriptions
        .where((description) {
          final itemClassification = VehicleEventCatalog.classify(description);
          return itemClassification.subcategory.code ==
              classification.subcategory.code;
        })
        .toList(growable: false);
    final operationTitle = matchingDescriptions.isNotEmpty
        ? matchingDescriptions.first
        : descriptions.isNotEmpty
        ? descriptions.first
        : classification.subcategory.defaultTitle;
    final vehicle = objectAt('vehicle');
    final amounts = objectAt('amounts');
    final parties = objectAt('parties');
    final dates = objectAt('dates');

    return DetectedVehicleOperation(
      categoryCode: classification.category.code,
      categoryLabel: classification.category.label,
      subcategoryCode: classification.subcategory.code,
      subcategoryLabel: classification.subcategory.label,
      title: _cleanOperationTitle(operationTitle),
      mileage: _asInteger(vehicle['mileage'] ?? resultJson['mileage']),
      amount: _asDouble(
        amounts['total_including_tax'] ??
            amounts['total'] ??
            resultJson['amount'],
      ),
      currency: _nullableString(amounts['currency']) ?? 'EUR',
      providerName: _nullableString(parties['garage_name']),
      documentDate: _nullableString(dates['document_date']),
    );
  }

  String get userFacingSummary {
    final operation = detectedOperation;
    return '${operation.categoryLabel} : ${operation.title}';
  }

  List<Map<String, dynamic>> get usefulObservations {
    return objectListAt('observations')
        .where((item) {
          final text = [
            item['title'],
            item['explanation'],
          ].whereType<Object>().join(' ').toLowerCase();
          return !_containsExcludedUserInformation(text) &&
              !_containsAccountingCheck(text);
        })
        .toList(growable: false);
  }

  List<String> get usefulQuestions {
    return stringListAt('questions_to_ask')
        .where((question) {
          final text = question.toLowerCase();
          return !_containsExcludedUserInformation(text) &&
              !_containsAccountingCheck(text);
        })
        .toList(growable: false);
  }

  Map<String, dynamic> objectAt(String key) {
    final value = resultJson[key];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  List<Map<String, dynamic>> objectListAt(String key) {
    final value = resultJson[key];
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  List<String> stringListAt(String key) {
    final value = resultJson[key];
    if (value is! List) return const [];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? stringAt(String key) {
    final value = resultJson[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};

    for (final entry in source.entries) {
      final key = entry.key;
      if (_isPersonalIdentityKey(key)) continue;

      final value = entry.value;
      if (value is Map) {
        result[key] = _sanitizeMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value
            .map((item) {
              if (item is Map) {
                return _sanitizeMap(Map<String, dynamic>.from(item));
              }
              return item;
            })
            .toList(growable: false);
      } else {
        result[key] = value;
      }
    }

    final parties = result['parties'];
    if (parties is Map) {
      result['parties'] = <String, dynamic>{
        if (parties['garage_name'] != null)
          'garage_name': parties['garage_name'],
        if (parties['garage_address'] != null)
          'garage_address': parties['garage_address'],
      };
    }

    return result;
  }

  static bool _isPersonalIdentityKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    const blocked = <String>{
      'client',
      'client_name',
      'customer',
      'customer_name',
      'owner',
      'owner_name',
      'recipient',
      'recipient_name',
      'person_name',
      'address',
      'email',
      'phone',
      'telephone',
      'mobile',
      'contact',
      'client_address',
      'customer_address',
      'owner_address',
      'recipient_address',
      'billing_address',
      'client_email',
      'customer_email',
      'owner_email',
      'recipient_email',
      'client_phone',
      'customer_phone',
      'owner_phone',
      'recipient_phone',
      'billed_to',
      'invoice_to',
    };
    return blocked.contains(normalized);
  }

  static bool _containsExcludedUserInformation(String text) {
    return RegExp(
      r'\b(client|customer|nom du client|propriétaire|destinataire)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static bool _containsAccountingCheck(String text) {
    return RegExp(
      r'((tva|total ttc|total ht).*(cohérent|cohérence|coherence|vérifier|verification))|'
      r'((cohérent|cohérence|coherence|vérifier|verification).*(tva|total ttc|total ht))',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static String _sanitizeSummary(String value) {
    final lines = value
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !_containsExcludedUserInformation(line))
        .where((line) => !_containsAccountingCheck(line))
        .toList(growable: false);
    return lines.join(' ');
  }

  static String _cleanOperationTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 90) return trimmed;
    return '${trimmed.substring(0, 87).trimRight()}…';
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  static int? _asInteger(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}
