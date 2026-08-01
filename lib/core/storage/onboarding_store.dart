import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  static const _completedKey = 'autoclair.onboarding.completed';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<bool> isCompleted() async {
    return await _preferences.getBool(_completedKey) ?? false;
  }

  Future<void> setCompleted(bool value) async {
    await _preferences.setBool(_completedKey, value);
  }
}
