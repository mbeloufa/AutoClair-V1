import 'package:autoclair_app/features/vehicle_care/vehicle_assistant_brief.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant promotes only a programmed plausible recall', () {
    final brief = VehicleAssistantBrief.build(
      vehicle: _vehicle(model: 'Golf 7 2.0 TDI', mileage: 82000),
      bundle: VehicleCareBundle(
        dashboard: _dashboard(
          recalls: [
            {
              'match_id': 'recall-1',
              'status': 'SCHEDULED',
              'match_score': 0.95,
              'title': 'Campagne airbag',
              'brand': 'Volkswagen',
              'models_references': 'Golf VII et Golf VIII',
              'risks': 'Risque à contrôler',
              'consumer_actions': 'Contacter le réseau',
              'match_reason': 'Modèle compatible',
            },
          ],
        ),
        schedules: [
          VehicleMaintenanceSchedule.fromMap({
            'id': 'schedule-1',
            'title': 'Filtre à huile',
            'schedule_type': 'MAINTENANCE',
            'due_mileage': 80000,
            'status': 'ACTIVE',
            'priority': 'HIGH',
            'source_type': 'AUTOCLAIR_RULE',
            'reason': '',
          }),
        ],
        suggestions: const [],
        completedDocumentCount: 0,
      ),
      offerCount: 2,
      now: DateTime(2026, 8, 10),
    );

    expect(brief.items, hasLength(3));
    expect(brief.items.first.title, 'Rappel constructeur programmé');
    expect(brief.items.first.target, VehicleAssistantTarget.alerts);
    expect(brief.items[1].title, 'Entretien à rattraper');
    expect(brief.items[1].message, contains('Révision avec vidange'));
    expect(brief.items[2].target, VehicleAssistantTarget.offers);
  });

  test('unconfirmed recall candidate is not promoted as vehicle urgency', () {
    final brief = VehicleAssistantBrief.build(
      vehicle: _vehicle(model: 'Golf 7 2.0 TDI', mileage: 82000),
      bundle: VehicleCareBundle(
        dashboard: _dashboard(
          recalls: [
            {
              'match_id': 'recall-1',
              'status': 'TO_CHECK',
              'match_score': 0.98,
              'title': 'Campagne à confirmer',
              'brand': 'Volkswagen',
              'models_references': 'Golf VII',
              'risks': 'Information source',
              'consumer_actions': 'Vérifier le VIN',
              'match_reason': 'Modèle compatible',
            },
          ],
        ),
        schedules: const [],
        suggestions: const [],
        completedDocumentCount: 0,
      ),
      now: DateTime(2026, 8, 10),
    );

    expect(brief.isUpToDate, isTrue);
  });

  test('assistant trusts a programmed recall already matched by Supabase', () {
    final brief = VehicleAssistantBrief.build(
      vehicle: _vehicle(model: 'Golf 7 2.0 TDI', mileage: 82000),
      bundle: VehicleCareBundle(
        dashboard: _dashboard(
          recalls: [
            {
              'match_id': 'recall-1',
              'status': 'SCHEDULED',
              'match_score': 0.98,
              'title': 'Campagne utilitaire',
              'brand': 'Volkswagen',
              'models_references': 'Transporter T5, Caravelle et Multivan',
              'risks': 'Risque à contrôler',
              'consumer_actions': 'Contacter le réseau',
              'match_reason': 'Marque compatible',
            },
          ],
        ),
        schedules: const [],
        suggestions: const [],
        completedDocumentCount: 0,
      ),
      now: DateTime(2026, 8, 10),
    );

    expect(brief.isUpToDate, isFalse);
    expect(brief.items.first.title, 'Rappel constructeur programmé');
    expect(brief.items.first.message, 'Campagne utilitaire');
  });

  test('generic upcoming action opens the maintenance section', () {
    final brief = VehicleAssistantBrief.build(
      vehicle: _vehicle(model: '208', mileage: 50000),
      bundle: VehicleCareBundle(
        dashboard: _dashboard(
          upcomingActions: [
            {
              'id': 'deadline',
              'source_type': 'COMPLIANCE',
              'title': 'Contrôle technique',
              'message': 'À anticiper',
              'priority': 'HIGH',
              'status': 'ACTIVE',
              'due_at': '2026-10-10T09:00:00Z',
            },
          ],
        ),
        schedules: const [],
        suggestions: const [],
        completedDocumentCount: 0,
      ),
      now: DateTime(2026, 8, 10),
    );

    expect(brief.items.first.target, VehicleAssistantTarget.maintenance);
    expect(brief.items.first.actionLabel, 'Voir l’échéance');
  });

  test(
    'assistant asks for mileage before showing a commercial opportunity',
    () {
      final brief = VehicleAssistantBrief.build(
        vehicle: _vehicle(model: '208', mileage: null),
        bundle: VehicleCareBundle(
          dashboard: _dashboard(),
          schedules: const [],
          suggestions: const [],
          completedDocumentCount: 0,
        ),
        offerCount: 1,
        now: DateTime(2026, 8, 10),
      );

      expect(brief.items.first.title, 'Kilométrage à renseigner');
      expect(brief.items.first.target, VehicleAssistantTarget.mileage);
      expect(brief.items[1].target, VehicleAssistantTarget.offers);
    },
  );
}

Vehicle _vehicle({required String model, required int? mileage}) {
  final now = DateTime(2026, 8, 10);
  return Vehicle(
    id: 'vehicle-1',
    userId: 'user-1',
    make: 'Volkswagen',
    model: model,
    mileage: mileage,
    isPrimary: true,
    createdAt: now,
    updatedAt: now,
  );
}

VehicleCareDashboard _dashboard({
  List<Map<String, dynamic>> recalls = const [],
  List<Map<String, dynamic>> upcomingActions = const [],
}) {
  return VehicleCareDashboard.fromMap({
    'health': {
      'maintenance_score': 90,
      'safety_score': 90,
      'administrative_score': 90,
      'history_score': 90,
      'budget_tracking_score': 90,
      'sale_readiness_score': 90,
      'overall_status': 'GOOD',
      'reasons': const {},
      'metrics': const {},
    },
    'upcoming_actions': upcomingActions,
    'recalls': recalls,
    'risks': const [],
    'recent_events': const [],
    'expenses': {
      'total_last_12_months': 0,
      'total_all_time': 0,
      'by_category': const {},
    },
    'generated_at': '2026-08-10T08:00:00Z',
  });
}
