import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';

const _known = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  selfRegistrationEnabled: true,
  defaultLegalBasis: 2,
  privacyNoticeUri: 'https://acme.example/privacy',
  emailVerificationUrl: 'https://acme.example/verify-email',
);

const _fromToggle = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  emailVerificationUrl: 'https://acme.example/verify-email',
);

void main() {
  test('GivenATogglesAnswer_WhenMergedWithTheKnownScope_ThenPrivacyIsKept', () {
    // Given / When
    final merged = _fromToggle.withPrivacySettingsOf(_known);

    // Then
    expect(merged.defaultLegalBasis, 2);
    expect(merged.privacyNoticeUri, 'https://acme.example/privacy');
    expect(merged.googleSignInEnabled, isTrue);
    expect(merged.emailVerificationUrl, 'https://acme.example/verify-email');
  });

  test('GivenATogglesAnswer_WhenMergedWithTheKnownScope_ThenSignUpIsKept', () {
    // Given / When
    final merged = _fromToggle.withSelfRegistrationOf(_known);

    // Then
    expect(merged.selfRegistrationEnabled, isTrue);
    expect(merged.googleSignInEnabled, isTrue);
  });

  test('GivenEitherLink_WhenAsked_ThenTheLinksAreCustom', () {
    // Given / When / Then
    expect(_known.hasCustomEmailLinks, isTrue);
    expect(
      const Scope(id: 'x', name: 'x', description: '').hasCustomEmailLinks,
      isFalse,
    );
  });
}
