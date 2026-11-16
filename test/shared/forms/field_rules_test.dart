import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/forms/field_rules.dart';

void main() {
  // The shape the API's `EmailAddress()` rule accepts, and nothing stricter.
  for (final email in <String>[
    'a@b',
    'ada@example.com',
    'first.last+x@sub.d',
  ]) {
    test('GivenAnAddressTheApiTakes_WhenChecked_ThenItPasses: $email', () {
      // Given / When
      final plausible = isPlausibleEmail(email);

      // Then
      expect(plausible, isTrue);
    });
  }

  for (final email in <String>['ada', '@example.com', 'ada@', 'a@b@c', '']) {
    test('GivenAnAddressTheApiRefuses_WhenChecked_ThenItFails: $email', () {
      // Given / When
      final plausible = isPlausibleEmail(email);

      // Then
      expect(plausible, isFalse);
    });
  }

  test('GivenNoPassword_WhenValidated_ThenTheEmptyMessageIsGiven', () {
    // Given
    const password = '';

    // When
    final message = validateNewPassword(
      password,
      emptyMessage: 'Enter a password.',
    );

    // Then
    expect(message, 'Enter a password.');
  });

  test('GivenOnlySpaces_WhenValidated_ThenTheEmptyMessageIsGiven', () {
    // Given
    const password = '         ';

    // When
    final message = validateNewPassword(
      password,
      emptyMessage: 'Enter a password.',
    );

    // Then
    expect(message, 'Enter a password.');
  });

  test('GivenSevenCharacters_WhenValidated_ThenTheApiWordingIsGiven', () {
    // Given
    const password = '1234567';

    // When
    final message = validateNewPassword(
      password,
      emptyMessage: 'Enter a password.',
    );

    // Then
    expect(message, 'Password must be at least 8 characters.');
  });

  test('GivenEightCharacters_WhenValidated_ThenItPasses', () {
    // Given
    const password = '12345678';

    // When
    final message = validateNewPassword(
      password,
      emptyMessage: 'Enter a password.',
    );

    // Then
    expect(message, isNull);
  });
}
