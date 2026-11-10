/// Supabase publishable project configuration (NOT a secret).
/// Override with --dart-define for other organizations/deployments.
/// Never add service_role, secret, database password, or OAuth client secret here.
abstract final class SupabaseConfiguration {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://umlzqlbakfwzgadafhyy.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_gRPxXgSuM2RrjGvNDAHBaw_88UBwE4D',
  );
  static const mobileRedirect = 'pohantoonai://auth-callback';
}
