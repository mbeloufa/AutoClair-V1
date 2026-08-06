import 'package:autoclair_app/features/risk_forecast/risk_forecast_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile rejects impossible mileage and breakdown values', () {
    expect(
      () => _profile(currentMileage: -1).validate(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => _profile(repeatedBreakdowns12m: 21).validate(),
      throwsA(isA<FormatException>()),
    );
  });

  test('summary is factual and explicitly not a diagnosis', () {
    final assessment = RiskForecastAssessment(
      score: 52,
      level: RiskForecastLevel.elevated,
      dataConfidence: RiskForecastConfidence.strong,
      generatedAt: DateTime(2026, 8, 6),
      factors: const [
        RiskForecastFactor(
          code: 'MAINTENANCE_GAP',
          category: RiskForecastCategory.maintenance,
          title: 'Entretien à rapprocher',
          detail: 'Délai déclaré.',
          action: 'Programmez un contrôle.',
          points: 20,
          horizon: RiskForecastHorizon.thirtyDays,
          confidence: RiskForecastConfidence.strong,
          safetyCritical: false,
        ),
      ],
    );

    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Volkswagen Golf',
    );

    expect(summary, contains('Volkswagen Golf'));
    expect(summary, contains('52/100'));
    expect(summary, contains('Risque élevé'));
    expect(summary, contains('ne constitue ni un diagnostic mécanique'));
    expect(summary, isNot(contains('panne certaine')));
  });

  test('parses a recent stored assessment', () {
    final snapshot = RiskForecastSnapshot.fromMap({
      'id': 'assessment-1',
      'risk_score': 76,
      'risk_level': 'PRIORITY',
      'data_confidence': 'MEDIUM',
      'created_at': '2026-08-06T08:30:00Z',
    });

    expect(snapshot.id, 'assessment-1');
    expect(snapshot.score, 76);
    expect(snapshot.level, RiskForecastLevel.priority);
    expect(snapshot.dataConfidence, RiskForecastConfidence.medium);
    expect(snapshot.createdAt.isUtc, isTrue);
  });
}

RiskForecastProfile _profile({
  int currentMileage = 100000,
  int repeatedBreakdowns12m = 0,
}) {
  return RiskForecastProfile(
    vehicleId: 'vehicle-1',
    currentMileage: currentMileage,
    annualMileage: 12000,
    vehicleAgeYears: 5,
    monthsSinceService: 10,
    kmSinceService: 8000,
    shortTripsOften: false,
    intensiveUse: false,
    longImmobilization: false,
    maintenancePlanned: false,
    dashboardWarning: false,
    brakingConcern: false,
    tireConcern: false,
    startingConcern: false,
    engineCoolingConcern: false,
    repeatedBreakdowns12m: repeatedBreakdowns12m,
  );
}
