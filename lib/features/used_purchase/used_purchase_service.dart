import 'package:supabase_flutter/supabase_flutter.dart';

import 'used_purchase_models.dart';

class UsedPurchaseException implements Exception {
  const UsedPurchaseException(this.message);

  final String message;
}

class UsedPurchaseService {
  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const UsedPurchaseException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    return userId;
  }

  Future<UsedPurchaseProfile?> loadProfile() async {
    try {
      final row = await _client
          .from('used_vehicle_purchase_profiles')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
      if (row == null) return null;
      return UsedPurchaseProfile.fromMap(Map<String, dynamic>.from(row));
    } on UsedPurchaseException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return null;
      throw UsedPurchaseException(_message(error));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(UsedPurchaseProfile profile) async {
    profile.validate();
    try {
      await _client.from('used_vehicle_purchase_profiles').upsert({
        'user_id': _userId,
        ...profile.toMap(),
      }, onConflict: 'user_id');
    } on UsedPurchaseException {
      rethrow;
    } on PostgrestException catch (error) {
      throw UsedPurchaseException(_message(error));
    }
  }

  Future<void> saveAssessment({
    required UsedPurchaseProfile profile,
    required UsedPurchaseAssessment assessment,
  }) async {
    try {
      await _client.from('used_vehicle_purchase_assessments').insert({
        'user_id': _userId,
        'seller_type': profile.sellerType.databaseValue,
        'make': _nullIfEmpty(profile.make),
        'model': _nullIfEmpty(profile.model),
        'vehicle_year': profile.vehicleYear,
        'mileage': profile.mileage,
        'readiness_score': assessment.score,
        'decision_level': assessment.decisionLevel.databaseValue,
        'blocking_count': assessment.blockingCount,
        'warning_count': assessment.warningCount,
        'asking_price_eur': profile.askingPrice,
        'total_acquisition_cost_eur': assessment.totalAcquisitionCost,
        'remaining_budget_eur': assessment.remainingBudget,
        'checklist': assessment.items
            .map((item) => item.toMap())
            .toList(growable: false),
      });
    } on UsedPurchaseException {
      rethrow;
    } on PostgrestException catch (error) {
      throw UsedPurchaseException(_message(error));
    }
  }

  Future<List<UsedPurchaseSnapshot>> loadRecentAssessments() async {
    try {
      final rows = await _client
          .from('used_vehicle_purchase_assessments')
          .select(
            'id,created_at,make,model,readiness_score,decision_level,'
            'total_acquisition_cost_eur',
          )
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => UsedPurchaseSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on UsedPurchaseException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return const [];
      throw UsedPurchaseException(_message(error));
    }
  }

  static String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    final normalized = raw.toLowerCase();
    if (normalized.contains('jwt') || raw.contains('AUTH_REQUIRED')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (normalized.contains('relation')) {
      return 'L’assistant d’achat doit être installé sur Supabase.';
    }
    return 'Le dossier d’achat n’a pas pu être enregistré.';
  }
}
