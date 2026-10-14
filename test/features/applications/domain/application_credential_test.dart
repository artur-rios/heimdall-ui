import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential.dart';

void main() {
  test(
    'GivenAPickedDay_WhenTurnedIntoAnExpiry_ThenItIsTheEndOfThatLocalDayInUtc',
    () {
      // Given
      final picked = DateTime(2027, 3, 9);

      // When
      final expiry = credentialExpiryFor(picked);

      // Then
      expect(expiry.isUtc, isTrue);
      expect(expiry, DateTime(2027, 3, 9, 23, 59, 59, 999).toUtc());
    },
  );

  test('GivenEachState_WhenAskedForStatus_ThenLiveRevokedOrExpired', () {
    // Given
    const live = ApplicationCredential(id: 'c1', live: true);
    final revoked = ApplicationCredential(
      id: 'c2',
      live: false,
      revokedAt: DateTime.utc(2026, 10, 1),
    );
    final expired = ApplicationCredential(
      id: 'c3',
      live: false,
      expiresAt: DateTime.utc(2026, 1, 1),
    );

    // When / Then
    expect(live.status, CredentialStatus.live);
    expect(revoked.status, CredentialStatus.revoked);
    expect(expired.status, CredentialStatus.expired);
  });
}
