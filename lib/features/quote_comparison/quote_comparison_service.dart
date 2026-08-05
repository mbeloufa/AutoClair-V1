import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/finance/financial_impact_service.dart';
import '../../core/finance/saving_status.dart';
import 'quote_models.dart';

class QuoteComparisonException implements Exception {
  const QuoteComparisonException(this.message);

  final String message;
}

class QuoteDocumentOption {
  const QuoteDocumentOption({
    required this.id,
    required this.label,
    required this.createdAt,
  });

  final String id;
  final String label;
  final DateTime createdAt;
}

class QuoteComparisonService {
  final FinancialImpactService _financial = FinancialImpactService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<QuoteDocumentOption>> fetchQuoteDocuments() async {
    try {
      final rows = await _client
          .from('documents')
          .select('id,document_type,comment,created_at,status')
          .inFilter('document_type', const ['estimate', 'quote'])
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final date =
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final comment = row['comment']?.toString().trim();
            return QuoteDocumentOption(
              id: row['id'].toString(),
              label: comment == null || comment.isEmpty
                  ? 'Devis du ${_formatDate(date)}'
                  : comment,
              createdAt: date,
            );
          })
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw QuoteComparisonException(_message(error));
    } catch (_) {
      throw const QuoteComparisonException(
        "Les devis disponibles n'ont pas pu être chargés.",
      );
    }
  }

  Future<QuoteComparisonResult> compare(
    List<QuoteDocumentOption> selected,
  ) async {
    if (selected.length < 2 || selected.length > 3) {
      throw const QuoteComparisonException('Sélectionnez deux ou trois devis.');
    }

    try {
      final quotes = <QuoteSnapshot>[];
      for (final option in selected) {
        final analysis = await _client
            .from('document_analyses')
            .select('document_id,overall_confidence,result_json')
            .eq('document_id', option.id)
            .maybeSingle();
        if (analysis == null) {
          throw QuoteComparisonException(
            "L'analyse du document « ${option.label} » est absente.",
          );
        }
        final map = Map<String, dynamic>.from(analysis);
        quotes.add(
          QuoteSnapshot.fromAnalysis(
            documentId: option.id,
            label: option.label,
            analysis: map,
            confidence: _decimal(map['overall_confidence']),
          ),
        );
      }
      return QuoteComparisonResult.fromQuotes(quotes);
    } on QuoteComparisonException {
      rethrow;
    } on PostgrestException catch (error) {
      throw QuoteComparisonException(_message(error));
    } catch (_) {
      throw const QuoteComparisonException(
        "La comparaison des devis n'a pas pu être préparée.",
      );
    }
  }

  Future<void> confirmChoice({
    required String vehicleId,
    required QuoteComparisonResult comparison,
    required QuoteSnapshot chosen,
  }) async {
    final reference = comparison.quotes.first;
    if (reference.documentId == chosen.documentId) {
      throw const QuoteComparisonException(
        'Le premier devis est déjà le devis de référence.',
      );
    }
    final saving = reference.total - chosen.total;
    if (saving <= 0) {
      throw const QuoteComparisonException(
        "Le devis choisi n'est pas moins cher que le devis de référence.",
      );
    }

    try {
      await _client.from('quote_comparisons').insert({
        'vehicle_id': vehicleId,
        'reference_document_id': reference.documentId,
        'chosen_document_id': chosen.documentId,
        'reference_total': reference.total,
        'chosen_total': chosen.total,
        'saving_amount': saving,
        'comparison_json': {
          'quote_ids': comparison.quotes
              .map((quote) => quote.documentId)
              .toList(),
          'categories': comparison.categories,
        },
        'status': 'CONFIRMED',
      });
      await _financial.recordOpportunity(
        vehicleId: vehicleId,
        featureCode: 'QUOTE_COMPARISON',
        baselineAmount: reference.total,
        proposedAmount: chosen.total,
        calculationDetails: {
          'reference_document_id': reference.documentId,
          'chosen_document_id': chosen.documentId,
          'quote_count': comparison.quotes.length,
          'confidence':
              comparison.quotes.every((quote) => quote.confidence >= 0.75)
              ? 'HIGH'
              : 'MEDIUM',
        },
        status: SavingStatus.confirmed,
        sourceReference: 'quote-${reference.documentId}-${chosen.documentId}',
      );
    } on FinancialImpactException catch (error) {
      throw QuoteComparisonException(error.message);
    } on PostgrestException catch (error) {
      throw QuoteComparisonException(_message(error));
    }
  }

  static double _decimal(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  static String _message(PostgrestException error) {
    if (error.message.toLowerCase().contains('relation')) {
      return 'Le module de comparaison doit être installé sur Supabase.';
    }
    if (error.message.toLowerCase().contains('permission')) {
      return "Vous n'avez pas accès à ce document.";
    }
    return "La comparaison n'a pas pu être enregistrée.";
  }
}
