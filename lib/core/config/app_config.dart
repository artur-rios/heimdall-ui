import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Values supplied at build time with `--dart-define`.
///
/// Nothing is read from a file at runtime and nothing is compiled in as a
/// literal beyond the local default, so a deployment address never reaches the
/// repository.
class AppConfig {
  const AppConfig({
    required String apiBaseUrl,
    String? googleClientId,
    String? scopeId,
  }) : _rawApiBaseUrl = apiBaseUrl,
       _rawGoogleClientId = googleClientId,
       _rawScopeId = scopeId;

  /// Reads the configuration from the compile-time environment, falling back to
  /// the local API — heimdall-api's Docker Compose deployment on port 8080 — so
  /// the application runs with no flags at all.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'HEIMDALL_API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    googleClientId: String.fromEnvironment('HEIMDALL_GOOGLE_CLIENT_ID'),
    scopeId: String.fromEnvironment('HEIMDALL_SCOPE_ID'),
  );

  final String _rawApiBaseUrl;
  final String? _rawGoogleClientId;
  final String? _rawScopeId;

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

  /// The scope this build targets when no calling application named one.
  ///
  /// On the web the caller's value in session storage wins; this is what a
  /// desktop or mobile build, which has no such caller, falls back to.
  String? get scopeId {
    final raw = _rawScopeId;

    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Refuses to start a release build of an installed app whose API is not
  /// reached over TLS.
  ///
  /// The default is the local API in the clear, which is what a desktop or
  /// Android build gets when it is built without the define — so a forgotten
  /// flag would otherwise ship an app that sends passwords and tokens over
  /// plain HTTP. Only this machine's own API, at `localhost` or `127.0.0.1`,
  /// may be reached without TLS. Debug and profile builds are a developer's
  /// and are left alone, as is the web build, whose container build already
  /// insists on an address and whose page decides its own transport.
  ///
  /// Throws [InsecureApiBaseUrlError] when the address is refused.
  void requireSecureApi({bool release = kReleaseMode, bool web = kIsWeb}) {
    if (!release || web) {
      return;
    }

    final uri = Uri.tryParse(apiBaseUrl);
    final scheme = uri?.scheme.toLowerCase();
    final host = uri?.host.toLowerCase();

    if (scheme == 'https' && host != null && host.isNotEmpty) {
      return;
    }

    if (scheme == 'http' && _localHosts.contains(host)) {
      return;
    }

    throw InsecureApiBaseUrlError(apiBaseUrl);
  }

  static const Set<String> _localHosts = <String>{'localhost', '127.0.0.1'};
}

/// A release build was given an API address it must not send credentials to.
class InsecureApiBaseUrlError extends Error {
  InsecureApiBaseUrlError(this.apiBaseUrl);

  /// The address that was refused.
  final String apiBaseUrl;

  @override
  String toString() =>
      'InsecureApiBaseUrlError: HEIMDALL_API_BASE_URL is "$apiBaseUrl", but a '
      'release build only talks to an https:// API (or to http://localhost '
      'and http://127.0.0.1 on this machine). Rebuild with '
      '--dart-define=HEIMDALL_API_BASE_URL=https://<your API>.';
}
