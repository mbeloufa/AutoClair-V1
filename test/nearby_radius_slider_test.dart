import 'package:autoclair_app/features/home/nearby_radius_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('radius slider displays its value without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    double value = 20;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NearbyRadiusSlider(
              value: value,
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    expect(find.text('20 km'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
