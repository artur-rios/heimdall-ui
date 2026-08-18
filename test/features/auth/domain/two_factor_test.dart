import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/auth/domain/two_factor.dart';

void main() {
  group('TwoFactorStatus', () {
    test('GivenBothMethods_WhenRead_ThenBothAreListed', () {
      // Given
      const status = TwoFactorStatus(
        isActive: true,
        appEnabled: true,
        emailEnabled: true,
      );

      // When
      final methods = status.methods;

      // Then
      expect(methods, <TwoFactorMethod>[
        TwoFactorMethod.app,
        TwoFactorMethod.email,
      ]);
    });

    test('GivenOneMethod_WhenRead_ThenOnlyThatOneIsListed', () {
      // Given
      const status = TwoFactorStatus(isActive: true, emailEnabled: true);

      // When
      final methods = status.methods;

      // Then
      expect(methods, <TwoFactorMethod>[TwoFactorMethod.email]);
    });

    // A caller who never set it up is answered with every flag false, which is
    // "off" rather than "unknown".
    test('GivenNoConfiguration_WhenRead_ThenItIsSimplyOff', () {
      // Given
      const status = TwoFactorStatus();

      // When / Then
      expect(status.isActive, isFalse);
      expect(status.methods, isEmpty);
      expect(status.remainingRecoveryCodes, 0);
    });
  });

  group('TwoFactorSetup', () {
    // AF-09e — the secret is what keeps a failed render from blocking setup,
    // so pulling it out of the URI has to be reliable.
    test('GivenAnOtpAuthUri_WhenSecretRead_ThenItIsExtracted', () {
      // Given
      const setup = TwoFactorSetup(
        method: TwoFactorMethod.app,
        otpAuthUri:
            'otpauth://totp/Heimdall:ada@example.com?secret=JBSWY3DPEHPK3PXP'
            '&issuer=Heimdall',
      );

      // When
      final secret = setup.secret;

      // Then
      expect(secret, 'JBSWY3DPEHPK3PXP');
    });

    test('GivenNoUri_WhenSecretRead_ThenItIsNull', () {
      // Given
      const setup = TwoFactorSetup(method: TwoFactorMethod.email);

      // When
      final secret = setup.secret;

      // Then
      expect(secret, isNull);
    });

    test('GivenAUriWithoutASecret_WhenSecretRead_ThenItIsNull', () {
      // Given
      const setup = TwoFactorSetup(
        method: TwoFactorMethod.app,
        otpAuthUri: 'otpauth://totp/Heimdall:ada@example.com?issuer=Heimdall',
      );

      // When
      final secret = setup.secret;

      // Then
      expect(secret, isNull);
    });

    test('GivenAnUnparseableUri_WhenSecretRead_ThenItIsNull', () {
      // Given
      const setup = TwoFactorSetup(
        method: TwoFactorMethod.app,
        otpAuthUri: ':::not a uri:::',
      );

      // When
      final secret = setup.secret;

      // Then
      expect(secret, isNull);
    });
  });

  group('TwoFactorMethod', () {
    // The wire values are the API's; getting one wrong would have it check a
    // code against the wrong secret.
    test('GivenTheMethods_WhenRead_ThenTheirWireValuesAreTheApis', () {
      // Given / When / Then
      expect(TwoFactorMethod.app.wireValue, 'App');
      expect(TwoFactorMethod.email.wireValue, 'Email');
    });
  });
}
