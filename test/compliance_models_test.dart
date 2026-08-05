import 'package:autoclair_app/features/compliance/compliance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overdue and critical items are urgent', () {
    final overdue = ComplianceItem(
      id: '1',
      type: 'TECHNICAL_CONTROL',
      title: 'Contrôle technique',
      message: '',
      status: 'ACTIVE',
      priority: 'MEDIUM',
      sourceType: 'MANUAL',
      dueDate: DateTime(2025, 1, 1),
    );
    final critical = ComplianceItem(
      id: '2',
      type: 'RECALL',
      title: 'Rappel',
      message: '',
      status: 'ACTIVE',
      priority: 'CRITICAL',
      sourceType: 'OPEN_DATA',
    );
    expect(overdue.isUrgent, isTrue);
    expect(critical.isUrgent, isTrue);
  });

  test('completed items are not overdue', () {
    final item = ComplianceItem(
      id: '1',
      type: 'INSURANCE',
      title: 'Assurance',
      message: '',
      status: 'COMPLETED',
      priority: 'HIGH',
      sourceType: 'MANUAL',
      dueDate: DateTime(2020),
    );
    expect(item.isOverdue, isFalse);
  });
}
