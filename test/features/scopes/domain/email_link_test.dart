import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/scopes/domain/email_link.dart';

void main() {
  test('GivenAnHttpsLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final error = validateEmailLink('https://app.example.com/verify-email');

    // Then
    expect(error, isNull);
  });

  test('GivenAnHttpLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final error = validateEmailLink('http://localhost:8080/verify-email');

    // Then
    expect(error, isNull);
  });

  test('GivenAHashRoutedLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final error = validateEmailLink('https://app.example.com/#/verify-email');

    // Then
    expect(error, isNull);
  });

  test('GivenAnEmptyOrBlankLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final errors = <String?>[
      validateEmailLink(null),
      validateEmailLink(''),
      validateEmailLink('   '),
    ];

    // Then
    expect(errors, everyElement(isNull));
  });

  test('GivenARelativePath_WhenValidated_ThenItIsRefused', () {
    // Given / When
    final error = validateEmailLink('/verify-email');

    // Then
    expect(error, 'Enter a full link starting with https:// or http://.');
  });

  test('GivenAnotherScheme_WhenValidated_ThenItIsRefused', () {
    // Given / When
    final error = validateEmailLink('ftp://app.example.com/verify-email');

    // Then
    expect(error, 'Enter a full link starting with https:// or http://.');
  });

  test('GivenALinkWithoutAHost_WhenValidated_ThenItIsRefused', () {
    // Given / When
    final error = validateEmailLink('https:///verify-email');

    // Then
    expect(error, 'Enter a full link starting with https:// or http://.');
  });

  test('GivenALinkOverTheLimit_WhenValidated_ThenItIsRefused', () {
    // Given
    final link = 'https://app.example.com/${'a' * 2030}';

    // When
    final error = validateEmailLink(link);

    // Then
    expect(link.length, greaterThan(emailLinkMaxLength));
    expect(error, 'Use at most 2048 characters.');
  });

  test('GivenSurroundingSpaces_WhenNormalized_ThenTheyAreTrimmed', () {
    // Given / When
    final link = normalizeEmailLink('  https://app.example.com/x  ');

    // Then
    expect(link, 'https://app.example.com/x');
  });

  test('GivenABlankLink_WhenNormalized_ThenItIsNull', () {
    // Given / When
    final link = normalizeEmailLink('   ');

    // Then
    expect(link, isNull);
  });
}
