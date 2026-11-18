/// Supabase + Google config for the Wellin cloud project.
///
/// Override anytime with:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ... \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=xxxx.apps.googleusercontent.com
/// ```
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://abldyrbfxyogxhvyosvv.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFibGR5cmJmeHlvZ3hodnlvc3Z2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ3MzgzNjAsImV4cCI6MjExMDMxNDM2MH0.gcRn0zHo-m84o16CfEgm0cZgg44wzgrktBTFKfU5wk4',
  );

  /// OAuth Web client ID (used as serverClientId for Google idToken).
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '516820881204-9uu25vsjp1mj7t80j91e468g8n5583o1.apps.googleusercontent.com',
  );

  /// OAuth iOS client ID (passed as clientId on Apple platforms).
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '516820881204-h62uq4g8o6mue9thknk2kocrn8n2kvts.apps.googleusercontent.com',
  );

  /// Web base path without trailing slash (empty for `/`).
  /// GitHub Pages project site: `/wellin_expense_tracker`.
  static const webBasePath = String.fromEnvironment(
    'WEB_BASE_PATH',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT') &&
      !supabaseAnonKey.contains('YOUR_SUPABASE');
}
