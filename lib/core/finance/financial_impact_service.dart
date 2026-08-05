import 'package:supabase_flutter/supabase_flutter.dart';

import 'saving_status.dart';

class FinancialImpactException implements Exception {
  const FinancialImpactException(this.message);

  final String message;
}

class FinancialImpactService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> recordOpportunity({
    required String vehicleId,
    required String featureCode,
    required double baselineAmount,
    required double proposedAmount,
    required Map<String, dynamic> calculationDetails,
    SavingStatus status = SavingStatus.detected,
    String? sourceReference,
    DateTime? expiresAt,
  }) async {
    if (baselineAmount < 0 || proposedAmount < 0) {
      throw const FinancialImpactException(
        'Les montants utilisés pour calculer une économie sont invalides.',
      );
    }

    final saving = baselineAmount - proposedAmount;
    if (saving <= 0) {
      throw const FinancialImpactException(
        "Cette proposition ne génère pas d'économie positive.",
      );
    }

    try {
      final row = await _client
          .from('saving_opportunities')
          .insert({
            'vehicle_id': vehicleId,
            'feature_code': featureCode,
            'baseline_amount': baselineAmount,
            'proposed_amount': proposedAmount,
            'potential_saving': saving,
            'calculation_details': calculationDetails,
            'confidence_level': _confidenceFromDetails(calculationDetails),
            'status': status.databaseValue,
            'source_reference': sourceReference,
            'expires_at': expiresAt?.toIso8601String(),
            if (status == SavingStatus.confirmed)
              'confirmed_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return row['id'].toString();
    } on PostgrestException catch (error) {
      throw FinancialImpactException(_message(error));
    } catch (_) {
      throw const FinancialImpactException(
        "L'économie n'a pas pu être enregistrée.",
      );
    }
  }

  Future<void> updateStatus({
    required String opportunityId,
    required SavingStatus status,
  }) async {
    try {
      await _client
          .from('saving_opportunities')
          .update({
            'status': status.databaseValue,
            'confirmed_at': status == SavingStatus.confirmed
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('id', opportunityId);
    } on PostgrestException catch (error) {
      throw FinancialImpactException(_message(error));
    } catch (_) {
      throw const FinancialImpactException(
        "L'état de l'économie n'a pas pu être mis à jour.",
      );
    }
  }

  Future<void> recordCost({
    required String vehicleId,
    required String category,
    required String subcategory,
    required double amount,
    required DateTime eventDate,
    int? mileageKm,
    String sourceType = 'MANUAL',
    String? sourceReference,
    String? note,
    bool isRecurring = false,
    int? recurrenceMonths,
  }) async {
    if (amount < 0 || mileageKm != null && mileageKm < 0) {
      throw const FinancialImpactException(
        'Le montant ou le kilométrage est invalide.',
      );
    }

    try {
      await _client.from('vehicle_cost_entries').insert({
        'vehicle_id': vehicleId,
        'category': category,
        'subcategory': subcategory,
        'amount': amount,
        'event_date': _dateOnly(eventDate),
        'mileage_km': mileageKm,
        'source_type': sourceType,
        'source_reference': sourceReference,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'is_recurring': isRecurring,
        'recurrence_months': recurrenceMonths,
      });
    } on PostgrestException catch (error) {
      throw FinancialImpactException(_message(error));
    } catch (_) {
      throw const FinancialImpactException(
        "La dépense n'a pas pu être enregistrée.",
      );
    }
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _confidenceFromDetails(Map<String, dynamic> details) {
    final explicit = details['confidence']?.toString().trim().toUpperCase();
    if (explicit == 'HIGH' || explicit == 'MEDIUM' || explicit == 'LOW') {
      return explicit!;
    }
    return 'MEDIUM';
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    if (raw.contains('AUTH_REQUIRED') || raw.toLowerCase().contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('VEHICLE_FORBIDDEN')) {
      return "Ce véhicule n'est plus accessible.";
    }
    if (raw.contains('AMOUNT_INVALID')) {
      return 'Le montant est invalide.';
    }
    return "L'enregistrement financier a échoué.";
  }
}
