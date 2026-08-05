import 'package:autoclair_app/features/charging_optimizer/charging_optimizer_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a stored charging profile', () {
    final profile = VehicleChargingProfile.fromMap({
      'consumption_kwh_per_100km': '17.5',
      'usual_charge_kwh': 42,
      'reference_price_per_kwh': '0.39',
      'max_charging_power_kw': 130,
      'battery_capacity_kwh': '77',
      'connector': 'ccs',
    });

    expect(profile.consumptionKwhPer100Km, 17.5);
    expect(profile.usualChargeKwh, 42);
    expect(profile.referencePricePerKwh, 0.39);
    expect(profile.maxChargingPowerKw, 130);
    expect(profile.batteryCapacityKwh, 77);
    expect(profile.connector, 'ccs');
  });

  test('uses any connector when the stored value is empty', () {
    final profile = VehicleChargingProfile.fromMap({
      'consumption_kwh_per_100km': 18,
      'usual_charge_kwh': 40,
      'reference_price_per_kwh': 0.45,
      'max_charging_power_kw': 100,
      'connector': '  ',
    });

    expect(profile.connector, 'any');
  });
}
