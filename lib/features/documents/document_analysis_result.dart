import 'document_type_catalog.dart';

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

    return DocumentAnalysisResult(
      id: map['id']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      summary: map['summary']?.toString().trim() ?? '',
      overallConfidence: _asDouble(map['overall_confidence']) ?? 0,
      resultJson: rawResult is Map
          ? Map<String, dynamic>.from(rawResult)
          : const {},
      declaredDocumentType: _nullableString(
        map['declared_document_type'] ?? map['document_type'],
      ),
    );
  }

  String get confidenceLabel => '${(overallConfidence * 100).round()} %';

  String get detectedTypeLabel {
    // Les catégories ajoutées par l'utilisateur restent la référence visible :
    // le modèle historique peut encore les rapprocher temporairement d'un
    // ordre de réparation ou d'un type indéterminé.
    if (declaredDocumentType == 'technical_inspection_report' ||
        declaredDocumentType == 'other') {
      return DocumentTypeCatalog.labelFor(declaredDocumentType);
    }

    final detectedType = resultJson['document_type_detected']?.toString();
    if (DocumentTypeCatalog.isSelectable(detectedType)) {
      return DocumentTypeCatalog.labelFor(detectedType);
    }

    if (DocumentTypeCatalog.isSelectable(declaredDocumentType)) {
      return DocumentTypeCatalog.labelFor(declaredDocumentType);
    }

    return 'Type non déterminé';
  }

  String get readabilityLabel {
    final quality = objectAt('document_quality');
    return switch (quality['readability']?.toString()) {
      'good' => 'Bonne',
      'partial' => 'Partielle',
      'poor' => 'Faible',
      _ => 'Non déterminée',
    };
  }

  Map<String, dynamic> objectAt(String key) {
    final value = resultJson[key];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  List<Map<String, dynamic>> objectListAt(String key) {
    final value = resultJson[key];
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  List<String> stringListAt(String key) {
    final value = resultJson[key];
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? stringAt(String key) {
    final value = resultJson[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
