import 'package:autoclair_app/features/tire_inspection/tire_inspection_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tire photo journey exposes six unique required slots', () {
    expect(TirePhotoSlot.values, hasLength(6));
    expect(
      TirePhotoSlot.values.map((slot) => slot.apiValue).toSet(),
      hasLength(6),
    );
    expect(TirePhotoSlot.frontLeftTread.apiValue, 'FRONT_LEFT_TREAD');
    expect(TirePhotoSlot.rearSidewall.apiValue, 'REAR_SIDEWALL');
  });

  test('parses a structured safety result without inventing a depth', () {
    final result = TireInspectionResult.fromJson({
      'status': 'READY',
      'global_status': 'REPLACE_SOON',
      'summary': 'Usure visible à faire contrôler.',
      'professional_message': 'Cette analyse ne remplace pas un professionnel.',
      'replacement_recommended': true,
      'front_dimension': '205/55 R16',
      'rear_dimension': '205/55 R16',
      'wheels': [
        for (final position in [
          'FRONT_LEFT',
          'FRONT_RIGHT',
          'REAR_LEFT',
          'REAR_RIGHT',
        ])
          {
            'position': position,
            'condition': 'REPLACE_SOON',
            'confidence': 'MEDIUM',
            'tread_assessment': 'Témoin visuellement proche lorsque visible.',
            'visible_findings': ['Usure visible'],
            'retake_required': false,
            'retake_reason': null,
          },
      ],
      'sidewalls': [
        for (final axle in ['FRONT', 'REAR'])
          {
            'axle': axle,
            'dimension': '205/55 R16',
            'load_speed_index': '91V',
            'brand': 'Exemple',
            'model': 'Exemple',
            'tire_type': 'ALL_SEASON',
            'markings': ['3PMSF'],
            'dot_code': null,
            'confidence': 'MEDIUM',
            'retake_required': false,
            'retake_reason': null,
          },
      ],
      'photo_quality': [
        for (final slot in TirePhotoSlot.values)
          {
            'slot': slot.apiValue,
            'status': 'GOOD',
            'reason': 'Photo exploitable',
          },
      ],
    });

    expect(result.globalLevel, TireInspectionLevel.replaceSoon);
    expect(result.replacementRecommended, isTrue);
    expect(result.frontDimension, '205/55 R16');
    expect(result.wheels, hasLength(4));
    expect(result.sidewalls, hasLength(2));
    expect(result.needsRetake, isFalse);
  });

  test('retake slots stay explicit', () {
    final result = TireInspectionResult.fromJson({
      'status': 'NEEDS_RETAKE',
      'global_status': 'UNKNOWN',
      'summary': 'Photo insuffisante.',
      'professional_message':
          'Contrôle professionnel recommandé en cas de doute.',
      'replacement_recommended': false,
      'front_dimension': null,
      'rear_dimension': null,
      'wheels': const [],
      'sidewalls': const [],
      'photo_quality': [
        {
          'slot': 'FRONT_LEFT_TREAD',
          'status': 'RETAKE',
          'reason': 'Photo floue',
        },
      ],
    });

    expect(result.needsRetake, isTrue);
    expect(result.retakeSlots, contains('FRONT_LEFT_TREAD'));
  });
  test('user-facing tire levels use simple everyday wording', () {
    expect(
      tireInspectionLevelLabel(TireInspectionLevel.ok),
      'Rien d’inquiétant visible',
    );
    expect(
      tireInspectionLevelLabel(TireInspectionLevel.replaceSoon),
      'À changer bientôt',
    );
    expect(
      tireInspectionLevelLabel(TireInspectionLevel.replaceNow),
      'À changer rapidement',
    );
    expect(
      tireInspectionLevelLabel(TireInspectionLevel.urgentProfessionalCheck),
      'Faites contrôler rapidement',
    );
  });
}
