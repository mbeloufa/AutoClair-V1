import 'document_type_catalog.dart';

class DocumentHistoryItem {
  const DocumentHistoryItem({
    required this.id,
    required this.documentType,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.errorCode,
    this.comment,
  });

  final String id;
  final String documentType;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorCode;
  final String? comment;

  factory DocumentHistoryItem.fromMap(Map<String, dynamic> map) {
    return DocumentHistoryItem(
      id: map['id']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? 'unknown',
      status: map['status']?.toString() ?? 'draft',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? ''),
      errorCode: _nullableString(map['error_code']),
      comment: _nullableString(map['comment']),
    );
  }

  String get typeLabel => DocumentTypeCatalog.labelFor(documentType);

  String get statusLabel {
    return switch (status) {
      'draft' => 'Prêt à analyser',
      'uploaded' => 'Prêt à analyser',
      'queued' => 'En attente',
      'processing' => 'Analyse en cours',
      'completed' => 'Analyse terminée',
      'failed' => 'Analyse à relancer',
      _ => 'État inconnu',
    };
  }

  bool get canStartAnalysis =>
      status == 'draft' ||
      status == 'uploaded' ||
      status == 'queued' ||
      status == 'failed';

  bool get isCompleted => status == 'completed';

  bool get isProcessing => status == 'processing';

  bool get canDelete => !isProcessing;

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
