import 'package:autoclair_app/features/charging_prices/charging_station_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse une offre comparable et calcule ses libellés', () {
    final offer = ChargingStationOffer.fromJson({
      'station_id': 'FRTESTP1',
      'station_name': 'Borne République',
      'network_name': 'Réseau Test',
      'operator_name': 'Opérateur Test',
      'operator_phone': '01 02 03 04 05',
      'address': '1 place de la République 21000 Dijon',
      'latitude': 47.322,
      'longitude': 5.0415,
      'distance_km': 3.42,
      'max_power_kw': 150,
      'connectors': ['Combo CCS', 'Type 2'],
      'point_count': 4,
      'is_free': false,
      'pricing_kind': 'kwh',
      'pricing_comparable': true,
      'unit_price_per_kwh': 0.49,
      'session_fee': 1.0,
      'estimated_cost': 20.6,
      'tariff_text': '0,49 €/kWh + 1 € par session',
      'payment_at_terminal': true,
      'payment_card': true,
      'payment_other': false,
      'access_condition': 'Accès libre',
      'reservation': false,
      'hours': '24/7',
      'accessibility': 'Accessible mais non réservé PMR',
      'updated_at': '2026-08-01T00:00:00Z',
    });

    expect(offer.displayName, 'Borne République');
    expect(offer.hasPhone, isTrue);
    expect(offer.connectors, contains('Combo CCS'));
    expect(offer.pricingLabel(40), '≈ 20,60 €');
    expect(offer.pricingDetail(40), contains('0,49 €/kWh'));
  });

  test('un tarif complexe reste non comparable', () {
    final offer = ChargingStationOffer.fromJson({
      'station_id': 'FRTESTP2',
      'station_name': 'Station de recharge',
      'network_name': 'Réseau B',
      'operator_name': 'Opérateur B',
      'address': '2 rue Exemple 21000 Dijon',
      'latitude': 47.32,
      'longitude': 5.04,
      'distance_km': 2,
      'max_power_kw': 22,
      'connectors': ['Type 2'],
      'point_count': 2,
      'is_free': false,
      'pricing_kind': 'complex',
      'pricing_comparable': false,
      'estimated_cost': null,
      'tariff_text': '0,40 €/kWh puis 0,10 €/minute après 2 heures',
      'payment_at_terminal': false,
      'payment_card': false,
      'payment_other': true,
      'reservation': false,
    });

    expect(offer.displayName, 'Réseau B');
    expect(offer.pricingLabel(40), 'Tarif non comparable');
    expect(offer.hasTariffText, isTrue);
  });
}
