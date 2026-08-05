import 'package:autoclair_app/core/finance/saving_status.dart';
import 'package:autoclair_app/features/vehicle_budget/vehicle_budget_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('budget separates confirmed and potential savings', () {
    final summary = VehicleBudgetSummary.calculate(
      entries: [
        VehicleCostEntry(
          id: '1',
          vehicleId: 'v1',
          category: 'FUEL',
          subcategory: 'E10',
          amount: 100,
          eventDate: DateTime(2026, 7, 1),
          sourceType: 'MANUAL',
        ),
        VehicleCostEntry(
          id: '2',
          vehicleId: 'v1',
          category: 'INSURANCE',
          subcategory: 'Prime',
          amount: 600,
          eventDate: DateTime(2026, 1, 1),
          sourceType: 'MANUAL',
        ),
      ],
      opportunities: [
        SavingOpportunitySummary(
          id: 's1',
          featureCode: 'FUEL_OPTIMIZER',
          baselineAmount: 80,
          proposedAmount: 75,
          potentialSaving: 5,
          status: SavingStatus.confirmed,
          createdAt: DateTime(2026, 7, 1),
        ),
        SavingOpportunitySummary(
          id: 's2',
          featureCode: 'QUOTE_COMPARISON',
          baselineAmount: 500,
          proposedAmount: 450,
          potentialSaving: 50,
          status: SavingStatus.detected,
          createdAt: DateTime(2026, 7, 2),
        ),
      ],
      distanceKm: 10000,
      now: DateTime(2026, 8, 5),
    );

    expect(summary.totalLast12Months, 700);
    expect(summary.confirmedSavings, 5);
    expect(summary.potentialSavings, 50);
    expect(summary.costPerKm, closeTo(0.07, 0.0001));
  });

  test('cost per kilometre stays unavailable without distance history', () {
    final summary = VehicleBudgetSummary.calculate(
      entries: const [],
      opportunities: const [],
    );
    expect(summary.costPerKm, isNull);
  });
}
