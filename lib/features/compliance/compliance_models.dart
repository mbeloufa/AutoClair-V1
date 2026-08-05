class ComplianceItem {
  const ComplianceItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.status,
    required this.priority,
    required this.sourceType,
    this.dueDate,
    this.sourceUrl,
    this.confidence,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String status;
  final String priority;
  final String sourceType;
  final DateTime? dueDate;
  final String? sourceUrl;
  final double? confidence;

  bool get isOverdue {
    final due = dueDate;
    if (due == null || status == 'COMPLETED' || status == 'DISMISSED') {
      return false;
    }
    final now = DateTime.now();
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isUrgent =>
      isOverdue || priority == 'CRITICAL' || priority == 'HIGH';

  String get typeLabel => switch (type) {
    'TECHNICAL_CONTROL' => 'Contrôle technique',
    'INSURANCE' => 'Assurance',
    'RECALL' => 'Rappel constructeur',
    'MAINTENANCE' => 'Entretien de sécurité',
    'DOCUMENT' => 'Document',
    'ZFE' => 'Crit’Air et ZFE',
    _ => 'À vérifier',
  };

  factory ComplianceItem.fromMap(Map<String, dynamic> map) {
    return ComplianceItem(
      id: map['id']?.toString() ?? '',
      type: map['item_type']?.toString() ?? 'OTHER',
      title: map['title']?.toString() ?? 'Échéance',
      message: map['message']?.toString() ?? '',
      status: map['status']?.toString() ?? 'ACTIVE',
      priority: map['priority']?.toString() ?? 'MEDIUM',
      sourceType: map['source_type']?.toString() ?? 'MANUAL',
      dueDate: DateTime.tryParse(map['due_date']?.toString() ?? ''),
      sourceUrl: _text(map['source_url']),
      confidence: _decimal(map['confidence']),
    );
  }
}

class ComplianceOverview {
  const ComplianceOverview({required this.items});

  final List<ComplianceItem> items;

  List<ComplianceItem> get urgent => items
      .where((item) => item.isUrgent && item.status == 'ACTIVE')
      .toList(growable: false);

  List<ComplianceItem> get upcoming {
    final values = items
        .where((item) => !item.isUrgent && item.status == 'ACTIVE')
        .toList();
    values.sort((left, right) {
      final leftDate = left.dueDate ?? DateTime(9999);
      final rightDate = right.dueDate ?? DateTime(9999);
      return leftDate.compareTo(rightDate);
    });
    return values;
  }
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double? _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
