import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/config/app_config.dart';

void main() {
  test('GivenNoDefine_WhenReadFromEnvironment_ThenFallsBackToLocalhost', () {
    // Given the suite runs without --dart-define

    // When
    final config = AppConfig.fromEnvironment();

    // Then
    expect(config.apiBaseUrl, 'http://localhost:5000');
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
}
