import 'package:autoclair_app/features/vehicle_inspection/vehicle_inspection_calculator.dart';
import 'package:autoclair_app/features/vehicle_inspection/vehicle_inspection_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete good inspection is reassuring', () {
    final assessment = VehicleInspectionCalculator.assess(
      _profile(
        checks: {
          for (final area in VehicleInspectionArea.values)
            area: VehicleInspectionStatus.good,
        },
      ),
    );

    expect(assessment.score, 100);
    expect(assessment.completenessPercent, 100);
    expect(assessment.level, VehicleInspectionLevel.reassuring);
    expect(assessment.findings, isEmpty);
  });

  test('urgent braking concern always requires priority action', () {
    final assessment = VehicleInspectionCalculator.assess(
      _profile(
        checks: {
          for (final area in VehicleInspectionArea.values)
            area: area == VehicleInspectionArea.brakes
                ? VehicleInspectionStatus.urgent
                : VehicleInspectionStatus.good,
        },
      ),
    );

    expect(assessment.immediateAction, isTrue);
    expect(assessment.level, VehicleInspectionLevel.priority);
    expect(assessment.findings.first.area, VehicleInspectionArea.brakes);
  });

  test('unchecked points remain visible through completeness', () {
    final checks = {
      for (final area in VehicleInspectionArea.values)
        area: VehicleInspectionStatus.notChecked,
    };
    checks[VehicleInspectionArea.bodywork] = VehicleInspectionStatus.good;
    final assessment = VehicleInspectionCalculator.assess(
      _profile(checks: checks),
    );

    expect(assessment.completenessPercent, 10);
    expect(assessment.level, VehicleInspectionLevel.monitor);
    expect(assessment.score, 100);
  });

  test('purchase without road test creates an explicit finding', () {
    final assessment = VehicleInspectionCalculator.assess(
      _profile(
        purpose: VehicleInspectionPurpose.purchase,
        checks: {
          for (final area in VehicleInspectionArea.values)
            area: VehicleInspectionStatus.good,
        },
      ),
    );

    expect(
      assessment.findings.any(
        (finding) => finding.code == 'PURCHASE_ROAD_TEST_MISSING',
      ),
      isTrue,
    );
    expect(assessment.score, 95);
  });

  test('professional check does not erase declared defects', () {
    final assessment = VehicleInspectionCalculator.assess(
      _profile(
        professionalCheckPlanned: true,
        checks: {
          for (final area in VehicleInspectionArea.values)
            area: area == VehicleInspectionArea.bodywork
                ? VehicleInspectionStatus.repair
                : VehicleInspectionStatus.good,
        },
      ),
    );

    expect(assessment.findings, hasLength(1));
    expect(assessment.level, VehicleInspectionLevel.action);
  });
}

VehicleInspectionProfile _profile({
  VehicleInspectionPurpose purpose = VehicleInspectionPurpose.routine,
  required Map<VehicleInspectionArea, VehicleInspectionStatus> checks,
  bool professionalCheckPlanned = false,
}) {
  return VehicleInspectionProfile(
    vehicleId: '11111111-1111-1111-1111-111111111111',
    purpose: purpose,
    checks: checks,
    roadTestCompleted: false,
    photosAvailable: false,
    professionalCheckPlanned: professionalCheckPlanned,
  );
}
