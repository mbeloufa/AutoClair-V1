import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/finance/financial_impact_service.dart';
import 'vehicle_budget_models.dart';

class VehicleBudgetException implements Exception {
  const VehicleBudgetException(this.message);

  final String message;
}

class VehicleBudgetService {
  final FinancialImpactService _financial = FinancialImpactService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<VehicleBudgetSummary> loadSummary({
    required String vehicleId,
    int? currentMileage,
  }) async {
    try {
      await _storeCurrentMileageSnapshot(
        vehicleId: vehicleId,
        mileage: currentMileage,
      );

      final costsRaw = await _client
          .from('vehicle_cost_entries')
          .select(
            'id,vehicle_id,category,subcategory,amount,event_date,mileage_km,'
            'source_type,source_reference,note',
          )
          .eq('vehicle_id', vehicleId)
          .order('event_date', ascending: false)
          .limit(250);

      final savingsRaw = await _client
          .from('saving_opportunities')
          .select(
            'id,feature_code,baseline_amount,proposed_amount,potential_saving,'
            'status,created_at,confirmed_at',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(100);

      final snapshotsRaw = await _client
          .from('vehicle_usage_snapshots')
          .select('mileage_km,snapshot_date')
          .eq('vehicle_id', vehicleId)
          .order('snapshot_date', ascending: true);

      final entries = (costsRaw as List)
          .map(
            (row) =>
                VehicleCostEntry.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      await _mergeExistingVehicleEvents(vehicleId: vehicleId, entries: entries);
      entries.sort((left, right) => right.eventDate.compareTo(left.eventDate));
      final opportunities = (savingsRaw as List)
          .map(
            (row) => SavingOpportunitySummary.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);

      int? distance;
      final snapshots = snapshotsRaw as List;
      if (snapshots.length >= 2) {
        final first = _integer((snapshots.first as Map)['mileage_km']);
        final last = _integer((snapshots.last as Map)['mileage_km']);
        if (first != null && last != null && last > first) {
          distance = last - first;
        }
      }

      return VehicleBudgetSummary.calculate(
        entries: entries,
        opportunities: opportunities,
        distanceKm: distance,
      );
    } on VehicleBudgetException {
      rethrow;
    } on PostgrestException catch (error) {
      throw VehicleBudgetException(_databaseMessage(error));
    } catch (_) {
      throw const VehicleBudgetException(
        "Le budget du véhicule n'a pas pu être chargé.",
      );
    }
  }

  Future<void> addExpense({
    required String vehicleId,
    required String category,
    required String subcategory,
    required double amount,
    required DateTime date,
    int? mileage,
    String? note,
    bool recurring = false,
    int? recurrenceMonths,
  }) {
    return _financial.recordCost(
      vehicleId: vehicleId,
      category: category,
      subcategory: subcategory,
      amount: amount,
      eventDate: date,
      mileageKm: mileage,
      note: note,
      isRecurring: recurring,
      recurrenceMonths: recurrenceMonths,
    );
  }

  Future<void> _mergeExistingVehicleEvents({
    required String vehicleId,
    required List<VehicleCostEntry> entries,
  }) async {
    try {
      final rows = await _client
          .from('vehicle_events')
          .select(
            'id,event_type,title,occurred_at,amount,mileage,status,'
            'source_document_id',
          )
          .eq('vehicle_id', vehicleId)
          .eq('status', 'COMPLETED')
          .order('occurred_at', ascending: false)
          .limit(250);
      final knownReferences = entries
          .map((entry) => entry.sourceReference)
          .whereType<String>()
          .toSet();
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final eventId = row['id']?.toString();
        final amount = _decimal(row['amount']);
        if (eventId == null || amount == null || amount <= 0) continue;
        final reference = 'event:$eventId';
        if (knownReferences.contains(reference)) continue;
        entries.add(
          VehicleCostEntry(
            id: reference,
            vehicleId: vehicleId,
            category: _eventCategory(row['event_type']?.toString()),
            subcategory: row['title']?.toString().trim().isNotEmpty == true
                ? row['title'].toString().trim()
                : 'Événement du carnet',
            amount: amount,
            eventDate:
                DateTime.tryParse(row['occurred_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            sourceType: 'VEHICLE_EVENT',
            mileageKm: _integer(row['mileage']),
            sourceReference: reference,
          ),
        );
      }
    } catch (_) {
      // Les dépenses manuelles restent disponibles sur les anciennes bases.
    }
  }

  static String _eventCategory(String? eventType) {
    final normalized = eventType?.toUpperCase() ?? '';
    if (normalized.contains('FUEL')) return 'FUEL';
    if (normalized.contains('CHARG')) return 'CHARGING';
    if (normalized.contains('INSUR')) return 'INSURANCE';
    if (normalized.contains('CONTROL') || normalized.contains('INSPECTION')) {
      return 'TECHNICAL_CONTROL';
    }
    if (normalized.contains('REPAIR') || normalized.contains('BODY')) {
      return 'REPAIR';
    }
    if (normalized.contains('MAINTENANCE') ||
        normalized.contains('SERVICE') ||
        normalized.contains('OIL') ||
        normalized.contains('BRAKE')) {
      return 'MAINTENANCE';
    }
    return 'OTHER';
  }

  static double? _decimal(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  Future<void> _storeCurrentMileageSnapshot({
    required String vehicleId,
    required int? mileage,
  }) async {
    if (mileage == null || mileage < 0) return;
    try {
      await _client.from('vehicle_usage_snapshots').upsert({
        'vehicle_id': vehicleId,
        'mileage_km': mileage,
        'snapshot_date': _dateOnly(DateTime.now()),
        'source_type': 'VEHICLE_PROFILE',
      }, onConflict: 'vehicle_id,snapshot_date');
    } catch (_) {
      // Le cockpit reste utilisable sans coût/km si l'instantané échoue.
    }
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _databaseMessage(PostgrestException error) {
    final raw = error.message;
    if (raw.toLowerCase().contains('relation') &&
        raw.toLowerCase().contains('does not exist')) {
      return 'Le socle financier doit être installé sur Supabase.';
    }
    if (raw.toLowerCase().contains('permission') ||
        raw.toLowerCase().contains('policy')) {
      return "Vous n'avez pas accès à ce budget.";
    }
    return "Les données financières n'ont pas pu être chargées.";
  }
}
