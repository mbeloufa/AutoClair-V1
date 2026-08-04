import 'package:autoclair_app/core/config/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase client configuration is embedded and safe', () {
    expect(AppEnv.isConfigured, isTrue);
    expect(AppEnv.supabaseUrl, startsWith('https://'));
    expect(AppEnv.supabaseUrl, endsWith('.supabase.co'));
    expect(AppEnv.supabasePublishableKey, isNotEmpty);
    expect(AppEnv.supabasePublishableKey.startsWith('sb_secret_'), isFalse);
  });
}
