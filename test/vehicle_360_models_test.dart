import 'package:autoclair_app/features/vehicle_insights/vehicle_360_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('precheck parses quality, market availability and latest report', () {
    final precheck = Vehicle360Precheck.fromMap({
      'vehicle_id': 'vehicle-1',
      'data_quality': {
        'score': 82,
        'can_generate': true,
        'missing': const [],
        'warnings': const ['aucune cote disponible'],
        'counts': {
          'vehicle_events': 6,
          'vehicle_maintenance_schedules': 2,
          'documents': 3,
        },
        'detected': {
          'brand': 'Volkswagen',
          'model': 'Golf',
          'year': '2020',
          'energy': 'Essence',
          'mileage': 68000,
        },
      },
      'market_data': {'available': false},
      'timing': {
        'status': 'data_insufficient',
        'score': 0,
        'reasons': const ['aucune cote'],
      },
      'latest_report': null,
    });

    expect(precheck.vehicleId, 'vehicle-1');
    expect(precheck.dataQuality.score, 82);
    expect(precheck.dataQuality.canGenerate, isTrue);
    expect(precheck.dataQuality.eventCount, 8);
    expect(precheck.dataQuality.documentCount, 3);
    expect(precheck.marketData.available, isFalse);
    expect(precheck.latestReport, isNull);
  });

  test('report parses maintenance, sale scenarios and traceable sources', () {
    final report = Vehicle360Report.fromEnvelope({
      'report': {
        'id': 'report-1',
        'vehicle_id': 'vehicle-1',
        'status': 'completed',
        'completed_at': '2026-08-04T08:37:00Z',
        'data_quality_score': 82,
        'overall_confidence_score': 80,
        'result_json': {
          'executive_summary': {
            'title': 'Suivi satisfaisant',
            'overall_status': 'monitor',
            'summary': 'Deux points restent à vérifier.',
            'confidence': 'high',
          },
          'data_quality': {
            'score': 82,
            'can_generate': true,
            'missing': const [],
            'warnings': const [],
            'counts': const {},
            'detected': const {},
          },
          'maintenance': {
            'positive_findings': [
              {
                'id': 'positive-1',
                'title': 'Vidanges suivies',
                'explanation': 'Les vidanges sont documentées.',
                'action': 'Conserver les factures.',
                'priority': 'information',
                'confidence': 'high',
                'source_ids': ['vehicle_events:event-1'],
              },
            ],
            'attention_findings': const [],
            'urgent_findings': const [],
            'next_12_month_actions': const [],
          },
          'usage_advice': const [],
          'sale_analysis': {
            'summary': 'Préparer les documents avant la vente.',
            'reasons': const ['dossier complet'],
            'preparation_actions': const [],
            'negotiation_points': const [],
            'timing': {
              'status': 'prepare_then_sell',
              'score': 70,
              'reasons': const ['compléter le contrôle technique'],
            },
            'scenarios': const [],
          },
          'market_data': {
            'available': true,
            'private_sale': {
              'valuation_date': '2026-08-04',
              'provider': 'provider',
              'valuation_type': 'private_sale',
              'value_low_eur': 17600,
              'value_mid_eur': 18400,
              'value_high_eur': 19300,
            },
            'trade_in': {
              'valuation_date': '2026-08-04',
              'provider': 'provider',
              'valuation_type': 'trade_in',
              'value_mid_eur': 16400,
            },
            'history': const [],
            'forecasts': [
              {
                'forecast_date': '2027-08-04',
                'horizon_months': 12,
                'scenario': 'central',
                'value_eur': 16900,
                'method': 'provider_residual_value',
              },
            ],
          },
          'questions_for_professional': const [
            'La distribution est-elle à jour ?',
          ],
          'limitations': const ['Version de boîte à confirmer'],
          'generation': {
            'ai_model': 'configured-model',
            'generated_at': '2026-08-04T08:37:00Z',
          },
        },
      },
      'scenarios': [
        {
          'scenario_code': 'sell_private_now',
          'expected_sale_value_eur': 18400,
          'explanation': 'Valeur centrale actuelle.',
          'details': const {},
        },
      ],
      'sources': [
        {
          'source_id': 'vehicle_events:event-1',
          'source_type': 'vehicle_events',
          'source_label': 'Révision',
          'confidence_level': 'high',
        },
      ],
    });

    expect(report.executiveSummary.statusLabel, 'Points à surveiller');
    expect(
      report.maintenance.positiveFindings.single.title,
      'Vidanges suivies',
    );
    expect(report.marketData.privateSale?.valueMid, 18400);
    expect(report.marketData.central12MonthForecast?.value, 16900);
    expect(report.marketData.projectedDepreciationAmount, 1500);
    expect(report.scenarios.single.title, 'Vendre à un particulier maintenant');
    expect(report.sources.single.typeLabel, 'Carnet');
    expect(report.actionCount, 0);
  });

  test('market history is sorted and duplicate current value is usable', () {
    final market = Vehicle360MarketData.fromMap({
      'available': true,
      'private_sale': {
        'valuation_date': '2026-08-04',
        'provider': 'provider',
        'valuation_type': 'private_sale',
        'value_mid_eur': 18000,
      },
      'history': [
        {
          'valuation_date': '2026-06-01',
          'provider': 'provider',
          'valuation_type': 'private_sale',
          'value_mid_eur': 19000,
        },
        {
          'valuation_date': '2026-01-01',
          'provider': 'provider',
          'valuation_type': 'private_sale',
          'value_mid_eur': 20500,
        },
      ],
      'forecasts': const [],
    });

    expect(market.history.first.valueMid, 20500);
    expect(market.history.last.valueMid, 19000);
    expect(market.privateSale?.valueMid, 18000);
  });
}
