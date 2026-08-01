class DocumentAnalysisResult {
  const DocumentAnalysisResult({
    required this.id,
    required this.documentId,
    required this.summary,
    required this.overallConfidence,
    required this.resultJson,
  });

  final String id;
  final String documentId;
  final String summary;
  final double overallConfidence;
  final Map<String, dynamic> resultJson;

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
    );
  }

  String get confidenceLabel => '${(overallConfidence * 100).round()} %';

  String get detectedTypeLabel {
    return switch (resultJson['document_type_detected']?.toString()) {
      'estimate' => 'Devis',
      'invoice' => 'Facture',
      'repair_order' => 'Ordre de réparation',
      _ => 'Type non déterminé',
    };
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

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
