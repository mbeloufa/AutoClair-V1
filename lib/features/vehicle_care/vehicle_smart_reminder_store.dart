import 'package:shared_preferences/shared_preferences.dart';

class VehicleSmartReminderStore {
  static const _prefix = 'autoclair.vehicle.smart_reminders.';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<bool> isEnabled(String vehicleId) async {
    return await _preferences.getBool(_key(vehicleId)) ?? false;
  }

  Future<void> setEnabled(String vehicleId, bool value) async {
    await _preferences.setBool(_key(vehicleId), value);
  }

  String _key(String vehicleId) => '$_prefix$vehicleId';
}
