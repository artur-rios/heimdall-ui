/// Values supplied at build time with `--dart-define`.
///
/// Nothing is read from a file at runtime and nothing is compiled in as a
/// literal beyond the local default, so a deployment address never reaches the
/// repository.
class AppConfig {
  const AppConfig({required String apiBaseUrl, String? googleClientId})
    : _rawApiBaseUrl = apiBaseUrl,
      _rawGoogleClientId = googleClientId;

  /// Reads the configuration from the compile-time environment, falling back to
  /// a local API so the application runs with no flags at all.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'HEIMDALL_API_BASE_URL',
      defaultValue: 'http://localhost:5000',
    ),
    googleClientId: String.fromEnvironment('HEIMDALL_GOOGLE_CLIENT_ID'),
  );

  final String _rawApiBaseUrl;
  final String? _rawGoogleClientId;

  /// The API root, without a trailing slash, so paths concatenate predictably.
  String get apiBaseUrl => _rawApiBaseUrl.endsWith('/')
      ? _rawApiBaseUrl.substring(0, _rawApiBaseUrl.length - 1)
      : _rawApiBaseUrl;

  /// The Google client id, or `null` when none was supplied. An undefined
  /// `String.fromEnvironment` reads as the empty string, which means the same
  /// thing as absent here.
  String? get googleClientId {
    final raw = _rawGoogleClientId;

    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Whether the Google sign-in control should be offered at all.
  bool get isGoogleSignInConfigured => googleClientId != null;
}
