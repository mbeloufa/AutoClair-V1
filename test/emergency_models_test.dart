import 'package:flutter_test/flutter_test.dart';
import 'package:autoclair_app/features/emergency_assistance/emergency_models.dart';
import 'package:autoclair_app/features/emergency_assistance/emergency_safety_engine.dart';

void main() {
  test('assessment parses bounded safety level and next questions', () {
    final result = EmergencyAssessmentResult.fromMap({
      'status': 'needs_information',
      'safety_level': 'assistance',
      'headline': 'Assistance recommandée',
      'summary': 'Un contrôle est nécessaire.',
      'reasons': ['Le véhicule est immobilisé.'],
      'actions': [
        {
          'priority': 1,
          'title': 'Rester en sécurité',
          'description': 'Ne pas entreprendre de manipulation risquée.',
        },
      ],
      'follow_up_questions': ['Le tableau de bord s’allume-t-il ?'],
      'image_observations': [],
      'uncertainties': ['Cause mécanique non confirmée.'],
      'call_emergency_services': false,
      'audio_note': '',
      'disclaimer': 'AutoClair ne confirme pas une panne.',
    });

    expect(result.level, EmergencySafetyLevel.assistance);
    expect(result.needsInformation, isTrue);
    expect(result.actions.single.priority, 1);
  });
}
