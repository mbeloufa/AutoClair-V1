import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 keeps every tool while prioritizing key moments', () {
    final home = _read('lib/features/home/home_page.dart');
    final center = _read('lib/features/home/action_center_page.dart');

    expect(home, contains("'Moments clés'"));
    expect(home, contains("'Choisir une situation'"));
    expect(home, contains("Text('Essentiel'"));

    for (final section in [
      'J’ai un imprévu',
      'J’achète ou je vends',
      'J’entretiens mon véhicule',
      'Je maîtrise mon budget',
    ]) {
      expect(center, contains("title: '$section'"));
    }

    expect(RegExp(r"route: '/[^']+'").allMatches(center).length, 26);
    expect(center, contains(r"ValueKey('action-tool-${tool.route}')"));
  });
}

String _read(String relativePath) => File(relativePath).readAsStringSync();
