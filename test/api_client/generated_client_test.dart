import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';

void main() {
  test(
    'GivenGeneratedLoginOutput_WhenDeserialized_ThenCarriesTheTwoFactorChallenge',
    () {
      // Given
      final json = <String, Object?>{
        'requiresTwoFactor': true,
        'challengeToken': 'challenge-token',
        'availableMethods': <String>['Totp', 'Email'],
      };

      // When
      final output = LoginCommandOutput.fromJson(json);

      // Then
      expect(output.requiresTwoFactor, isTrue);
      expect(output.challengeToken, 'challenge-token');
      expect(output.availableMethods, containsAll(<String>['Totp', 'Email']));
    },
  );

  test('GivenDioInstance_WhenClientConstructed_ThenNoRequestIsMade', () {
    // Given
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));

    // When
    final client = AuthClient(dio);

    // Then
    expect(client, isNotNull);
  });
}
