import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/config/app_config.dart';

void main() {
  test('GivenNoDefine_WhenReadFromEnvironment_ThenFallsBackToLocalhost', () {
    // Given the suite runs without --dart-define

    // When
    final config = AppConfig.fromEnvironment();

    // Then
    expect(config.apiBaseUrl, 'http://localhost:8080');
    expect(config.googleClientId, isNull);
  });

  test('GivenTrailingSlash_WhenConstructed_ThenBaseUrlIsNormalized', () {
    // Given
    const raw = 'https://api.example.com/';

    // When
    const config = AppConfig(apiBaseUrl: raw);

    // Then
    expect(config.apiBaseUrl, 'https://api.example.com');
  });

  test('GivenBlankGoogleClientId_WhenConstructed_ThenItIsTreatedAsAbsent', () {
    // Given
    const raw = '';

    // When
    const config = AppConfig(
      apiBaseUrl: 'https://api.example.com',
      googleClientId: raw,
    );

    // Then
    expect(config.googleClientId, isNull);
    expect(config.isGoogleSignInConfigured, isFalse);
  });

  // A release build talks to its API over TLS; only the local API, on this
  // machine, may be reached in the clear.
  for (final url in <String>[
    'http://heimdall.example.com',
    'http://10.0.2.2:8080',
    'http://localhost.example.com',
    'heimdall.example.com',
    'ftp://heimdall.example.com',
  ]) {
    test(
      'GivenAReleaseBuild_WhenTheApiIsNotHttps_ThenStartUpIsRefused $url',
      () {
        // Given
        final config = AppConfig(apiBaseUrl: url);

        // When
        void check() => config.requireSecureApi(release: true, web: false);

        // Then
        expect(
          check,
          throwsA(
            isA<InsecureApiBaseUrlError>().having(
              (error) => error.toString(),
              'message',
              allOf(contains('HEIMDALL_API_BASE_URL'), contains('https://')),
            ),
          ),
        );
      },
    );
  }

  for (final url in <String>[
    'https://heimdall.example.com',
    'HTTPS://heimdall.example.com/',
    'http://localhost:8080',
    'http://127.0.0.1:8080',
    'https://localhost',
  ]) {
    test('GivenAReleaseBuild_WhenTheApiIsAllowed_ThenStartUpGoesOn $url', () {
      // Given
      final config = AppConfig(apiBaseUrl: url);

      // When
      void check() => config.requireSecureApi(release: true, web: false);

      // Then
      expect(check, returnsNormally);
    });
  }

  // A debug or profile build is a developer's, pointed wherever they choose.
  test('GivenADebugBuild_WhenTheApiIsCleartext_ThenStartUpGoesOn', () {
    // Given
    const config = AppConfig(apiBaseUrl: 'http://heimdall.example.com');

    // When
    void check() => config.requireSecureApi(release: false, web: false);

    // Then
    expect(check, returnsNormally);
  });

  // The web build takes its address from the page's deployment, which the
  // container build already insists on; the check is for the installed apps.
  test('GivenAWebReleaseBuild_WhenTheApiIsCleartext_ThenStartUpGoesOn', () {
    // Given
    const config = AppConfig(apiBaseUrl: 'http://heimdall.example.com');

    // When
    void check() => config.requireSecureApi(release: true, web: true);

    // Then
    expect(check, returnsNormally);
  });

  // The build the suite runs as is not a release, so the defaults let the
  // local API through.
  test('GivenTheDefaults_WhenChecked_ThenTheLocalApiIsAccepted', () {
    // Given
    final config = AppConfig.fromEnvironment();

    // When / Then
    expect(config.requireSecureApi, returnsNormally);
  });
}
