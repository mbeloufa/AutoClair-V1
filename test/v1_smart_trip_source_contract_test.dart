import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smart trip V1 stays financial, bounded and privacy-first', () {
    final edge = File(
      'supabase/functions/analyze-smart-trip/index.ts',
    ).readAsStringSync();
    final page = File(
      'lib/features/smart_trip/smart_trip_page.dart',
    ).readAsStringSync();
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final home = File('lib/features/home/home_page.dart').readAsStringSync();
    final config = File('supabase/config.toml').readAsStringSync();
    for (final m in const [
      'https://router.hereapi.com/v8/routes',
      'https://geocode.search.hereapi.com/v1/geocode',
      'tolls[summaries]',
      'avoid[features]',
      'tollRoad',
      'HYBRID_70',
      'HYBRID_85',
      'MIN_SAVING_EUR',
      'MIN_SAVING_RATIO',
      'DETERMINISTIC_FINANCIAL_V1',
      'navigation_waypoints',
      'fuel[freeFlowSpeedTable]',
      'fuel[trafficSpeedTable]',
      'HERE_SPEED_TRAFFIC_CALIBRATED',
      'EV_NOT_SUPPORTED_V1',
    ]) {
      expect(edge, contains(m), reason: m);
    }
    expect(edge, isNot(contains('OPENAI_API_KEY')));
    expect(edge, isNot(contains('/v1/responses')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.upsert(')));
    for (final m in const [
      'Trajet intelligent',
      'Le meilleur compromis, en euros',
      'Analyser le meilleur compromis',
      'Temps supplémentaire maximum',
      'Utiliser ce trajet dans Google Maps',
      'Plans et Waze peuvent recalculer',
      'SharedPreferences',
      'La consommation est adaptée au profil de vitesse et au trafic',
      'V1 dédiée intégrera autonomie, recharge et prix des bornes',
    ]) {
      expect(page, contains(m), reason: m);
    }
    expect(page, isNot(contains('desiredAccuracy:')));
    expect(page, contains('locationSettings: const LocationSettings('));
    final compactPage = page
        .replaceAll(' ', '')
        .replaceAll('\t', '')
        .replaceAll('\r', '')
        .replaceAll('\n', '');
    expect(
      compactPage,
      isNot(contains('DropdownButtonFormField<Vehicle>(value:')),
    );
    expect(compactPage, contains('initialValue:_vehicle'));
    expect(router, contains("path: '/smart-trip'"));
    expect(router, contains('SmartTripPage()'));
    expect(home, contains("ValueKey('home-smart-trip-card')"));
    expect(home, contains("context.push<void>('/smart-trip')"));
    const functionMarker = '[functions.analyze-smart-trip]';
    final functionStart = config.indexOf(functionMarker);
    expect(functionStart, greaterThanOrEqualTo(0));
    final nextSection = config.indexOf(
      '\n[',
      functionStart + functionMarker.length,
    );
    final block = nextSection < 0
        ? config.substring(functionStart)
        : config.substring(functionStart, nextSection);
    expect(block, contains('verify_jwt = true'));
  });
}
