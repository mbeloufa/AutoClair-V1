import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard parses health, events, reminders and expenses', () {
    final dashboard = VehicleCareDashboard.fromMap({
      'health': {
        'maintenance_score': 82,
        'safety_score': 75,
        'administrative_score': 100,
        'history_score': 90,
        'budget_tracking_score': 60,
        'sale_readiness_score': 55,
        'overall_status': 'WATCH',
        'reasons': {
          'maintenance': {'due_soon': 1},
        },
        'metrics': {'current_mileage': 82400},
      },
      'upcoming_actions': [
        {
          'id': 'reminder-1',
          'source_type': 'SCHEDULE',
          'title': 'Vidange moteur',
          'message': 'Échéance indicative',
          'due_mileage': 85000,
          'priority': 'MEDIUM',
          'status': 'ACTIVE',
        },
      ],
      'recent_events': [
        {
          'id': 'event-1',
          'event_type': 'MAINTENANCE',
          'status': 'COMPLETED',
          'title': 'Révision',
          'occurred_at': '2026-08-01T12:00:00Z',
          'mileage': 82000,
          'amount': 249.90,
          'currency': 'EUR',
          'source_type': 'MANUAL',
          'user_confirmed': true,
        },
      ],
      'recalls': const [],
      'risks': const [],
      'expenses': {
        'total_last_12_months': 249.90,
        'total_all_time': 500,
        'by_category': {'MAINTENANCE': 249.90},
      },
      'generated_at': '2026-08-03T12:00:00Z',
    });

    expect(dashboard.health.maintenanceScore, 82);
    expect(dashboard.health.statusLabel, 'Points à surveiller');
    expect(dashboard.upcomingActions.single.dueMileage, 85000);
    expect(dashboard.recentEvents.single.typeLabel, 'Entretien');
    expect(dashboard.expenses.totalLast12Months, 249.90);
  });

  test('maintenance schedule detects overdue and due soon mileage', () {
    final overdue = VehicleMaintenanceSchedule.fromMap({
      'id': 'schedule-1',
      'title': 'Vidange',
      'schedule_type': 'MAINTENANCE',
      'due_mileage': 80000,
      'status': 'ACTIVE',
      'priority': 'MEDIUM',
      'source_type': 'AUTOCLAIR_RULE',
      'reason': '',
    });
    final soon = VehicleMaintenanceSchedule.fromMap({
      'id': 'schedule-2',
      'title': 'Filtre à air',
      'schedule_type': 'MAINTENANCE',
      'due_mileage': 83500,
      'status': 'ACTIVE',
      'priority': 'LOW',
      'source_type': 'AUTOCLAIR_RULE',
      'reason': '',
    });

    expect(overdue.isOverdue(currentMileage: 82000), isTrue);
    expect(soon.isDueSoon(currentMileage: 82000), isTrue);
  });

  test('event labels remain user friendly', () {
    expect(eventTypeLabel('INSPECTION'), 'Contrôle technique');
    expect(eventTypeLabel('RECALL'), 'Rappel constructeur');
    expect(eventTypeLabel('UNKNOWN'), 'Autre');
  });
}
