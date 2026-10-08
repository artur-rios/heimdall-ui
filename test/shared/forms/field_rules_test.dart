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
      expect(isPlausibleEmail(email), isTrue);
    });
  }

  for (final email in <String>['ada', '@example.com', 'ada@', 'a@b@c', '']) {
    test('GivenAnAddressTheApiRefuses_WhenChecked_ThenItFails: $email', () {
      expect(isPlausibleEmail(email), isFalse);
    });
  }

  test('GivenNoPassword_WhenValidated_ThenTheEmptyMessageIsGiven', () {
    expect(
      validateNewPassword('', emptyMessage: 'Enter a password.'),
      'Enter a password.',
    );
  });

  test('GivenOnlySpaces_WhenValidated_ThenTheEmptyMessageIsGiven', () {
    expect(
      validateNewPassword('         ', emptyMessage: 'Enter a password.'),
      'Enter a password.',
    );
  });

  test('GivenSevenCharacters_WhenValidated_ThenTheApiWordingIsGiven', () {
    expect(
      validateNewPassword('1234567', emptyMessage: 'Enter a password.'),
      'Password must be at least 8 characters.',
    );
  });

  test('GivenEightCharacters_WhenValidated_ThenItPasses', () {
    expect(
      validateNewPassword('12345678', emptyMessage: 'Enter a password.'),
      isNull,
    );
  });
}
