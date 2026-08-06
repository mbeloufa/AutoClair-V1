import 'package:autoclair_app/features/risk_forecast/risk_forecast_calculator.dart';
import 'package:autoclair_app/features/risk_forecast/risk_forecast_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthy recent profile remains low risk', () {
    final assessment = RiskForecastCalculator.assess(
      _profile(
        currentMileage: 45000,
        vehicleAgeYears: 4,
        monthsSinceService: 8,
        kmSinceService: 6000,
      ),
      generatedAt: DateTime(2026, 8, 6),
    );

    expect(assessment.level, RiskForecastLevel.low);
    expect(assessment.score, lessThan(20));
    expect(assessment.hasSafetyCritical, isFalse);
  });

  test('braking concern always requires priority control', () {
    final assessment = RiskForecastCalculator.assess(
      _profile(brakingConcern: true),
    );

    expect(assessment.level, RiskForecastLevel.priority);
    expect(assessment.hasSafetyCritical, isTrue);
    expect(
      assessment.factors.any((factor) => factor.code == 'BRAKING_SIGNAL'),
      isTrue,
    );
  });

  test('overdue maintenance creates an explainable factor', () {
    final assessment = RiskForecastCalculator.assess(
      _profile(monthsSinceService: 25, kmSinceService: 26000),
    );

    final factor = assessment.factors.singleWhere(
      (item) => item.code == 'MAINTENANCE_GAP',
    );
    expect(factor.points, 40);
    expect(factor.horizon, RiskForecastHorizon.thirtyDays);
    expect(factor.detail, contains('25 mois'));
    expect(factor.detail, contains('26000 km'));
  });

  test('planned maintenance lowers only the maintenance contribution', () {
    final unplanned = RiskForecastCalculator.assess(
      _profile(monthsSinceService: 25, kmSinceService: 26000),
    );
    final planned = RiskForecastCalculator.assess(
      _profile(
        monthsSinceService: 25,
        kmSinceService: 26000,
        maintenancePlanned: true,
      ),
    );

    expect(planned.score, lessThan(unplanned.score));
    expect(
      planned.factors
          .singleWhere((item) => item.code == 'MAINTENANCE_GAP')
          .points,
      26,
    );
  });

  test('repeated breakdowns and intensive use raise the level', () {
    final assessment = RiskForecastCalculator.assess(
      _profile(
        currentMileage: 170000,
        vehicleAgeYears: 12,
        annualMileage: 32000,
        intensiveUse: true,
        repeatedBreakdowns12m: 3,
      ),
    );

    expect(assessment.level, isNot(RiskForecastLevel.low));
    expect(
      assessment.factors.any((factor) => factor.code == 'REPEATED_BREAKDOWNS'),
      isTrue,
    );
  });

  test('age and mileage never become a certain diagnosis', () {
    final assessment = RiskForecastCalculator.assess(
      _profile(currentMileage: 220000, vehicleAgeYears: 18),
    );

    expect(assessment.hasSafetyCritical, isFalse);
    final summary = assessment.buildShareSummary(vehicleLabel: 'Véhicule test');
    expect(summary, contains('ni un diagnostic mécanique'));
    expect(summary, contains('ni une garantie de panne'));
  });
}

RiskForecastProfile _profile({
  int currentMileage = 80000,
  int annualMileage = 12000,
  int vehicleAgeYears = 5,
  int monthsSinceService = 8,
  int kmSinceService = 7000,
  bool shortTripsOften = false,
  bool intensiveUse = false,
  bool longImmobilization = false,
  bool maintenancePlanned = false,
  bool dashboardWarning = false,
  bool brakingConcern = false,
  bool tireConcern = false,
  bool startingConcern = false,
  bool engineCoolingConcern = false,
  int repeatedBreakdowns12m = 0,
}) {
  return RiskForecastProfile(
    vehicleId: 'vehicle-1',
    currentMileage: currentMileage,
    annualMileage: annualMileage,
    vehicleAgeYears: vehicleAgeYears,
    monthsSinceService: monthsSinceService,
    kmSinceService: kmSinceService,
    shortTripsOften: shortTripsOften,
    intensiveUse: intensiveUse,
    longImmobilization: longImmobilization,
    maintenancePlanned: maintenancePlanned,
    dashboardWarning: dashboardWarning,
    brakingConcern: brakingConcern,
    tireConcern: tireConcern,
    startingConcern: startingConcern,
    engineCoolingConcern: engineCoolingConcern,
    repeatedBreakdowns12m: repeatedBreakdowns12m,
  );
}
