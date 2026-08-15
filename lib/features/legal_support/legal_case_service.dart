import 'package:supabase_flutter/supabase_flutter.dart';

import 'legal_case_models.dart';

class LegalCaseService {
  LegalCaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('Une session utilisateur valide est nécessaire.');
    }
    return id;
  }

  Future<List<LegalVehicleOption>> fetchVehicles() async {
    final rows = await _client
        .from('vehicles')
        .select(
          'id,nickname,make,model,vehicle_year,mileage,registration_number,updated_at',
        )
        .eq('user_id', _userId)
        .order('updated_at', ascending: false);

    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => LegalVehicleOption.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<List<LegalDocumentOption>> fetchDocuments(String vehicleId) async {
    final rows = await _client
        .from('documents')
        .select('id,document_type,comment,status,created_at')
        .eq('user_id', _userId)
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false)
        .limit(30);

    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => LegalDocumentOption.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<String> createCase({
    required LegalVehicleOption vehicle,
    required LegalCaseCategory category,
    required String counterpartyType,
    required String description,
    required DateTime? eventDate,
    required double? amountEur,
    required bool writtenComplaint,
    required bool bodilyInjury,
    required bool courtStarted,
    required bool criminalIssue,
    required bool crossBorder,
    required Set<String> documentIds,
  }) async {
    final uid = _userId;
    final row = await _client
        .from('legal_cases')
        .insert({
          'user_id': uid,
          'vehicle_id': vehicle.id,
          'category': category.dbValue,
          'counterparty_type': counterpartyType,
          'status': 'collecting',
          'issue_description': description.trim(),
          'event_date': eventDate?.toIso8601String().split('T').first,
          'amount_eur': amountEur,
          'written_complaint': writtenComplaint,
          'bodily_injury': bodilyInjury,
          'court_started': courtStarted,
          'criminal_issue': criminalIssue,
          'cross_border': crossBorder,
        })
        .select('id')
        .single();

    final caseId = row['id'].toString();

    try {
      final facts = <Map<String, dynamic>>[
        {
          'case_id': caseId,
          'user_id': uid,
          'fact_key': 'vehicle',
          'label': 'Véhicule concerné',
          'value_text': vehicle.displayName,
          'source_kind': 'autoclair_vehicle',
          'source_id': vehicle.id,
          'confirmed': true,
          'is_critical': true,
        },
        if (vehicle.registrationNumber?.isNotEmpty == true)
          {
            'case_id': caseId,
            'user_id': uid,
            'fact_key': 'registration_number',
            'label': 'Immatriculation',
            'value_text': vehicle.registrationNumber,
            'source_kind': 'autoclair_vehicle',
            'source_id': vehicle.id,
            'confirmed': true,
            'is_critical': false,
          },
        if (vehicle.mileage != null)
          {
            'case_id': caseId,
            'user_id': uid,
            'fact_key': 'current_mileage',
            'label': 'Kilométrage enregistré',
            'value_text': '${vehicle.mileage} km',
            'source_kind': 'autoclair_vehicle',
            'source_id': vehicle.id,
            'confirmed': true,
            'is_critical': false,
          },
        if (eventDate != null)
          {
            'case_id': caseId,
            'user_id': uid,
            'fact_key': 'event_date',
            'label': 'Date indiquée par l’utilisateur',
            'value_text': eventDate.toIso8601String().split('T').first,
            'source_kind': 'user_confirmed',
            'confirmed': true,
            'is_critical': true,
          },
        if (amountEur != null)
          {
            'case_id': caseId,
            'user_id': uid,
            'fact_key': 'amount_eur',
            'label': 'Montant indiqué par l’utilisateur',
            'value_text': '${amountEur.toStringAsFixed(2)} EUR',
            'source_kind': 'user_confirmed',
            'confirmed': true,
            'is_critical': false,
          },
        {
          'case_id': caseId,
          'user_id': uid,
          'fact_key': 'written_complaint',
          'label': 'Réclamation écrite déjà envoyée',
          'value_text': writtenComplaint ? 'Oui' : 'Non',
          'source_kind': 'user_confirmed',
          'confirmed': true,
          'is_critical': false,
        },
      ];

      await _client.from('legal_case_facts').insert(facts);

      if (documentIds.isNotEmpty) {
        await _client
            .from('legal_case_documents')
            .insert(
              documentIds
                  .map(
                    (documentId) => {
                      'case_id': caseId,
                      'document_id': documentId,
                      'user_id': uid,
                      'role': 'supporting_document',
                    },
                  )
                  .toList(growable: false),
            );
      }
    } catch (_) {
      await _client
          .from('legal_cases')
          .delete()
          .eq('id', caseId)
          .eq('user_id', uid);
      rethrow;
    }

    return caseId;
  }

  Future<LegalAnalysisResult> analyzeCase(String caseId) async {
    final response = await _client.functions.invoke(
      'analyze-legal-case',
      body: {'case_id': caseId},
    );

    if (response.data is! Map) {
      throw StateError(
        'La réponse du service Litiges & démarches est invalide.',
      );
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['success'] != true) {
      throw StateError(
        data['message']?.toString() ??
            'L’analyse du dossier n’a pas pu être terminée.',
      );
    }

    final assessment = data['assessment'];
    if (assessment is! Map) {
      throw StateError('Le résultat du dossier est incomplet.');
    }

    return LegalAnalysisResult.fromMap(Map<String, dynamic>.from(assessment));
  }

  Future<LegalAnalysisResult> appendInformationAndAnalyze({
    required String caseId,
    required String additionalInformation,
  }) async {
    final uid = _userId;
    final current = await _client
        .from('legal_cases')
        .select('issue_description')
        .eq('id', caseId)
        .eq('user_id', uid)
        .single();

    final previous = current['issue_description']?.toString().trim() ?? '';
    final addition = additionalInformation.trim();
    if (addition.isEmpty) {
      return analyzeCase(caseId);
    }

    final combined = '$previous\n\nPrécision ajoutée : $addition';
    if (combined.length > 5000) {
      throw StateError(
        'Le dossier contient trop de texte. Raccourcissez la précision.',
      );
    }

    await _client
        .from('legal_cases')
        .update({'issue_description': combined, 'status': 'collecting'})
        .eq('id', caseId)
        .eq('user_id', uid);

    await _client.from('legal_case_facts').insert({
      'case_id': caseId,
      'user_id': uid,
      'fact_key': 'user_clarification',
      'label': 'Précision ajoutée par l’utilisateur',
      'value_text': addition,
      'source_kind': 'user_confirmed',
      'confirmed': true,
      'is_critical': false,
    });

    return analyzeCase(caseId);
  }

  Future<void> deleteCase(String caseId) async {
    await _client
        .from('legal_cases')
        .delete()
        .eq('id', caseId)
        .eq('user_id', _userId);
  }
}
