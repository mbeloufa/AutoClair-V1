import 'package:flutter_test/flutter_test.dart';
import 'package:autoclair_app/features/emergency_assistance/emergency_safety_engine.dart';

void main() {
  test('injury always produces stop and emergency services', () {
    final decision = EmergencySafetyDecision.evaluate(
      category: EmergencyCategory.other,
      flags: const EmergencySafetyFlags(injury: true),
    );

    expect(decision.level, EmergencySafetyLevel.stop);
    expect(decision.callEmergencyServices, isTrue);
  });

  test('brake loss always produces stop', () {
    final decision = EmergencySafetyDecision.evaluate(
      category: EmergencyCategory.noiseBehavior,
      flags: const EmergencySafetyFlags(brakeLoss: true),
    );

    expect(decision.level, EmergencySafetyLevel.stop);
  });

  test(
    'immobilized vehicle requests assistance without claiming a diagnosis',
    () {
      final decision = EmergencySafetyDecision.evaluate(
        category: EmergencyCategory.immobilized,
        flags: const EmergencySafetyFlags(),
      );

      expect(decision.level, EmergencySafetyLevel.assistance);
      expect(decision.callEmergencyServices, isFalse);
    },
  );

  test('warning light without critical flag stays at prompt check', () {
    final decision = EmergencySafetyDecision.evaluate(
      category: EmergencyCategory.warningLight,
      flags: const EmergencySafetyFlags(),
    );

    expect(decision.level, EmergencySafetyLevel.promptCheck);
  });

  test('critical rule wins over a normally lower-risk category', () {
    final decision = EmergencySafetyDecision.evaluate(
      category: EmergencyCategory.lockedOut,
      flags: const EmergencySafetyFlags(fuelSmellOrLeak: true),
    );

    expect(decision.level, EmergencySafetyLevel.stop);
  });
}
