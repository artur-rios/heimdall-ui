import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';

GoogleUser _user({String name = '', String email = ''}) =>
    GoogleUser(id: 'google-1', name: name, email: email);

void main() {
  // FR-GU-03 and AF-28d — the initials are what a missing picture falls back
  // to, so they have to be right for every shape of name.
  test('GivenAFullName_WhenInitialsRead_ThenTheFirstAndLastAreUsed', () {
    // Given
    final user = _user(name: 'Ada Lovelace');

    // When
    final initials = user.initials;

    // Then
    expect(initials, 'AL');
  });

  test('GivenThreeNames_WhenInitialsRead_ThenTheFirstAndLastAreUsed', () {
    // Given
    final user = _user(name: 'Ada Byron Lovelace');

    // When
    final initials = user.initials;

    // Then
    expect(initials, 'AL');
  });

  test('GivenOneName_WhenInitialsRead_ThenOneLetterIsUsed', () {
    // Given
    final user = _user(name: 'Ada');

    // When
    final initials = user.initials;

    // Then
    expect(initials, 'A');
  });

  test('GivenExtraSpaces_WhenInitialsRead_ThenTheyAreIgnored', () {
    // Given
    final user = _user(name: '  Ada   Lovelace  ');

    // When
    final initials = user.initials;

    // Then
    expect(initials, 'AL');
  });

  test('GivenALowercaseName_WhenInitialsRead_ThenTheyAreUppercased', () {
    // Given
    final user = _user(name: 'ada lovelace');

    // When
    final initials = user.initials;

    // Then
    expect(initials, 'AL');
  });

  test('GivenNoName_WhenInitialsRead_ThenTheEmailIsUsed', () {
    // Given
    final user = _user(email: 'ada@example.com');

    // When
    final initials = user.initials;

    // Then
    expect(initials, 'A');
  });

  test('GivenNothingAtAll_WhenInitialsRead_ThenAQuestionMarkIsUsed', () {
    // Given
    final user = _user();

    // When
    final initials = user.initials;

    // Then
    expect(initials, '?');
  });

  // Runes rather than code units: a name starting with a non-BMP character
  // must not be cut in half.
  test('GivenAnEmojiName_WhenInitialsRead_ThenTheCharacterSurvives', () {
    // Given
    final user = _user(name: '🌟 Star');

    // When
    final initials = user.initials;

    // Then
    expect(initials, '🌟S');
  });
}
