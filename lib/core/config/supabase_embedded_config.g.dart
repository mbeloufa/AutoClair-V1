/// Generated automatically by the AutoClair installer.
///
/// This file contains only the public Supabase client configuration.
/// Never place a service_role or sb_secret_ key here.
abstract final class EmbeddedSupabaseConfig {
  static const url = 'https://zkzocdtxebacxcrkrkzu.supabase.co';

  static const publishableKey =
      'sb_publishable_5TR1D4S2Fby26SautfNE0Q_WEBb88u3';

  static bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;
}
