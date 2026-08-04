import 'supabase_embedded_config.g.dart';

abstract final class AppEnv {
  static const _definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const _definedSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static const _definedSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const _definedSupabaseGenericKey = String.fromEnvironment(
    'SUPABASE_KEY',
  );

  static const passwordResetRedirect = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT',
  );

  static String get supabaseUrl =>
      _firstNonEmpty([_definedSupabaseUrl, EmbeddedSupabaseConfig.url]);

  static String get supabasePublishableKey => _firstNonEmpty([
    _definedSupabasePublishableKey,
    _definedSupabaseAnonKey,
    _definedSupabaseGenericKey,
    EmbeddedSupabaseConfig.publishableKey,
  ]);

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  static bool get usesEmbeddedConfiguration =>
      _definedSupabaseUrl.trim().isEmpty &&
      _definedSupabasePublishableKey.trim().isEmpty &&
      _definedSupabaseAnonKey.trim().isEmpty &&
      _definedSupabaseGenericKey.trim().isEmpty &&
      EmbeddedSupabaseConfig.isConfigured;

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}
