import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('tire control is visual, accepts gallery and validates every photo', () {
    final page = source(
      'lib/features/tire_inspection/tire_inspection_page.dart',
    );
    final service = source(
      'lib/features/tire_inspection/tire_inspection_service.dart',
    );
    final models = source(
      'lib/features/tire_inspection/tire_inspection_models.dart',
    );
    final edge = source('supabase/functions/analyze-tire-inspection/index.ts');

    expect(page, contains('assets/tire_inspection/tire_intro.png'));
    expect(page, contains('assets/tire_inspection/tire_tread_photo.png'));
    expect(page, contains('assets/tire_inspection/tire_sidewall_photo.png'));
    expect(page, contains('ImageSource.camera'));
    expect(page, contains('ImageSource.gallery'));
    expect(page, contains('Vérification de la photo'));
    expect(page, contains('Photo validée'));
    expect(page, isNot(contains('_CarGuidePainter')));
    expect(page, isNot(contains('AnimationController')));
    expect(
      page,
      contains('Elle ne constitue ni un contrôle, ni un diagnostic'),
    );

    expect(models, contains('class TirePhotoQualityCheck'));
    expect(service, contains('Future<TirePhotoQualityCheck> validatePhoto'));
    expect(service, contains("'action': 'validate_photo'"));
    expect(service, contains('discardPhoto'));

    expect(edge, contains('action === "validate_photo"'));
    expect(edge, contains('validateSinglePhoto'));
    expect(edge, contains('detail: "low"'));
    expect(edge, contains('Do NOT diagnose wear'));
    expect(edge, contains('detail: "original"'));

    for (final asset in [
      'assets/tire_inspection/tire_intro.png',
      'assets/tire_inspection/tire_tread_photo.png',
      'assets/tire_inspection/tire_sidewall_photo.png',
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
      expect(File(asset).lengthSync(), greaterThan(5000), reason: asset);
    }
  });
}
