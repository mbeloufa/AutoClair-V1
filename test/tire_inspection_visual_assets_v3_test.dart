import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tire inspection exposes one dedicated guide for every photo slot', () {
    final page = File(
      'lib/features/tire_inspection/tire_inspection_page.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const expectedAssets = <String>[
      'assets/tire_inspection/tire_intro.png',
      'assets/tire_inspection/tire_front_left.png',
      'assets/tire_inspection/tire_front_right.png',
      'assets/tire_inspection/tire_rear_left.png',
      'assets/tire_inspection/tire_rear_right.png',
      'assets/tire_inspection/tire_front_sidewall.png',
      'assets/tire_inspection/tire_rear_sidewall.png',
    ];

    expect(pubspec, contains('assets/tire_inspection/'));
    expect(page, contains('class _PhotoGuideImage extends StatelessWidget'));
    expect(page, contains('class _TireExperienceHero extends StatelessWidget'));

    for (final asset in expectedAssets) {
      expect(page, contains(asset), reason: '$asset must be wired in the UI');
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: '$asset must exist');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(400000));
      expect(
        bytes.take(8).toList(),
        equals(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
      );
    }

    for (final slot in <String>[
      'TirePhotoSlot.frontLeftTread',
      'TirePhotoSlot.frontRightTread',
      'TirePhotoSlot.rearLeftTread',
      'TirePhotoSlot.rearRightTread',
      'TirePhotoSlot.frontSidewall',
      'TirePhotoSlot.rearSidewall',
    ]) {
      expect(page, contains(slot));
    }

    final guideStart = page.indexOf('class _PhotoGuideImage');
    expect(guideStart, greaterThanOrEqualTo(0));
    final guideTail = page.substring(guideStart);
    expect(guideTail, isNot(contains('tire_tread_photo.png')));
    expect(guideTail, isNot(contains('tire_sidewall_photo.png')));
    expect(page, contains('BoxFit.cover'));
    expect(page, contains('aspectRatio: 4 / 3'));
  });
}
