import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/finance/financial_impact_service.dart';
import '../../core/finance/saving_status.dart';
import 'insurance_models.dart';

class InsuranceReviewException implements Exception {
  const InsuranceReviewException(this.message);

  final String message;
}

class InsuranceReviewService {
  final FinancialImpactService _financial = FinancialImpactService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<InsuranceSnapshot>> fetchSnapshots(String vehicleId) async {
    try {
      final rows = await _client
          .from('insurance_contract_snapshots')
          .select(
            'id,vehicle_id,provider_name,annual_premium,deductible_amount,'
            'snapshot_date,expiry_date,assistance_zero_km,replacement_vehicle,'
            'contract_number_masked,document_id,source_type,guarantees',
          )
          .eq('vehicle_id', vehicleId)
          .order('snapshot_date', ascending: false);
      final snapshots = (rows as List)
          .map(
            (row) => InsuranceSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

      final documents = await _client
          .from('documents')
          .select('id,vehicle_id,created_at')
          .eq('vehicle_id', vehicleId)
          .inFilter('document_type', const [
            'insurance',
            'insurance_certificate',
          ])
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(20);
      final knownDocumentIds = snapshots
          .map((snapshot) => snapshot.documentId)
          .whereType<String>()
          .toSet();
      for (final raw in documents as List) {
        final document = Map<String, dynamic>.from(raw as Map);
        final documentId = document['id'].toString();
        if (knownDocumentIds.contains(documentId)) continue;
        final analysis = await _client
            .from('document_analyses')
            .select('result_json')
            .eq('document_id', documentId)
            .maybeSingle();
        if (analysis == null) continue;
        final snapshot = InsuranceSnapshot.fromAnalysis(
          documentId: documentId,
          vehicleId: vehicleId,
          createdAt:
              DateTime.tryParse(document['created_at']?.toString() ?? '') ??
              DateTime.now(),
          analysis: Map<String, dynamic>.from(analysis),
        );
        if (snapshot.annualPremium > 0) snapshots.add(snapshot);
      }

      snapshots.sort(
        (left, right) => right.snapshotDate.compareTo(left.snapshotDate),
      );
      return List.unmodifiable(snapshots);
    } on PostgrestException catch (error) {
      throw InsuranceReviewException(_message(error));
    } catch (_) {
      throw const InsuranceReviewException(
        "Les informations d'assurance n'ont pas pu être chargées.",
      );
    }
  }

  Future<void> addManualSnapshot({
    required String vehicleId,
    required String providerName,
    required double annualPremium,
    required DateTime snapshotDate,
    DateTime? expiryDate,
    double? deductible,
    bool? assistanceZeroKm,
    bool? replacementVehicle,
    String? contractNumber,
    List<String> guarantees = const [],
  }) async {
    if (annualPremium < 0 || deductible != null && deductible < 0) {
      throw const InsuranceReviewException(
        'La prime ou la franchise est invalide.',
      );
    }
    try {
      await _client.from('insurance_contract_snapshots').insert({
        'vehicle_id': vehicleId,
        'provider_name': providerName.trim(),
        'annual_premium': annualPremium,
        'deductible_amount': deductible,
        'snapshot_date': _dateOnly(snapshotDate),
        'expiry_date': expiryDate == null ? null : _dateOnly(expiryDate),
        'assistance_zero_km': assistanceZeroKm,
        'replacement_vehicle': replacementVehicle,
        'contract_number_masked': InsuranceSnapshot.maskContractNumber(
          contractNumber,
        ),
        'source_type': 'MANUAL',
        'guarantees': guarantees,
      });
    } on PostgrestException catch (error) {
      throw InsuranceReviewException(_message(error));
    }
  }

  Future<void> confirmSaving({
    required String vehicleId,
    required InsuranceSnapshot previous,
    required InsuranceSnapshot selected,
  }) async {
    if (selected.annualPremium >= previous.annualPremium) {
      throw const InsuranceReviewException(
        "La nouvelle prime ne génère pas d'économie annuelle.",
      );
    }
    try {
      await _financial.recordOpportunity(
        vehicleId: vehicleId,
        featureCode: 'INSURANCE_REVIEW',
        baselineAmount: previous.annualPremium,
        proposedAmount: selected.annualPremium,
        calculationDetails: {
          'previous_provider': previous.providerName,
          'selected_provider': selected.providerName,
          'deductible_before': previous.deductible,
          'deductible_after': selected.deductible,
          'guarantees_removed': previous.guarantees
              .where((item) => !selected.guarantees.contains(item))
              .toList(),
          'confidence': 'MEDIUM',
        },
        status: SavingStatus.confirmed,
        sourceReference: 'insurance-${previous.id}-${selected.id}',
      );
    } on FinancialImpactException catch (error) {
      throw InsuranceReviewException(error.message);
    }
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _message(PostgrestException error) {
    if (error.message.toLowerCase().contains('relation')) {
      return "Le module d'assurance doit être installé sur Supabase.";
    }
    if (error.message.toLowerCase().contains('permission')) {
      return "Vous n'avez pas accès à ces informations.";
    }
    return "L'information d'assurance n'a pas pu être enregistrée.";
  }
}
