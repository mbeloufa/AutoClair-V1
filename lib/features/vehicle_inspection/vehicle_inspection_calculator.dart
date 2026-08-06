import 'vehicle_inspection_models.dart';

class VehicleInspectionCalculator {
  const VehicleInspectionCalculator._();

  static VehicleInspectionAssessment assess(VehicleInspectionProfile profile) {
    profile.validate();

    var penalty = 0;
    var checkedCount = 0;
    var positiveCount = 0;
    var immediateAction = false;
    final findings = <VehicleInspectionFinding>[];

    for (final area in VehicleInspectionArea.values) {
      final status = profile.statusOf(area);
      if (status == VehicleInspectionStatus.notChecked) continue;
      checkedCount++;

      if (status == VehicleInspectionStatus.good) {
        positiveCount++;
        continue;
      }

      penalty += switch (status) {
        VehicleInspectionStatus.monitor => 7,
        VehicleInspectionStatus.repair => 16,
        VehicleInspectionStatus.urgent => 28,
        VehicleInspectionStatus.notChecked || VehicleInspectionStatus.good => 0,
      };

      if (status == VehicleInspectionStatus.urgent && area.safetyCritical) {
        immediateAction = true;
      }

      findings.add(
        VehicleInspectionFinding(
          code: '${area.databaseValue}_${status.databaseValue}',
          area: area,
          status: status,
          title: '${area.label} — ${status.label}',
          action: area.action,
        ),
      );
    }

    if (profile.purpose == VehicleInspectionPurpose.purchase &&
        !profile.roadTestCompleted) {
      penalty += 5;
      findings.add(
        const VehicleInspectionFinding(
          code: 'PURCHASE_ROAD_TEST_MISSING',
          area: VehicleInspectionArea.equipment,
          status: VehicleInspectionStatus.monitor,
          title: 'Essai routier non réalisé',
          action: 'Ne finalisez pas l’achat sans un essai adapté et autorisé.',
        ),
      );
    }

    if (profile.purpose == VehicleInspectionPurpose.returnLease &&
        !profile.photosAvailable) {
      findings.add(
        const VehicleInspectionFinding(
          code: 'RETURN_PHOTOS_MISSING',
          area: VehicleInspectionArea.bodywork,
          status: VehicleInspectionStatus.monitor,
          title: 'État photographique non préparé',
          action: 'Conservez vos propres photos datées avant la restitution.',
        ),
      );
    }

    final score = (100 - penalty).clamp(0, 100).toInt();
    final completenessPercent =
        (checkedCount * 100 ~/ VehicleInspectionArea.values.length);
    final hasRepair = findings.any(
      (finding) =>
          finding.status == VehicleInspectionStatus.repair ||
          finding.status == VehicleInspectionStatus.urgent,
    );

    final level = immediateAction || score < 45
        ? VehicleInspectionLevel.priority
        : hasRepair || score < 70
        ? VehicleInspectionLevel.action
        : score < 90 || completenessPercent < 100
        ? VehicleInspectionLevel.monitor
        : VehicleInspectionLevel.reassuring;

    findings.sort((left, right) {
      final statusOrder = _statusRank(
        right.status,
      ).compareTo(_statusRank(left.status));
      if (statusOrder != 0) return statusOrder;
      return left.area.index.compareTo(right.area.index);
    });

    return VehicleInspectionAssessment(
      score: score,
      level: level,
      completenessPercent: completenessPercent,
      immediateAction: immediateAction,
      checkedCount: checkedCount,
      positiveCount: positiveCount,
      findings: List.unmodifiable(findings),
    );
  }

  static int _statusRank(VehicleInspectionStatus status) {
    return switch (status) {
      VehicleInspectionStatus.urgent => 4,
      VehicleInspectionStatus.repair => 3,
      VehicleInspectionStatus.monitor => 2,
      VehicleInspectionStatus.good => 1,
      VehicleInspectionStatus.notChecked => 0,
    };
  }
}
