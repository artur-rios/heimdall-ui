/// What the API reports about the caller's own two-factor configuration.
class TwoFactorStatus {
  const TwoFactorStatus({
    this.isActive = false,
    this.appEnabled = false,
    this.emailEnabled = false,
    this.remainingRecoveryCodes = 0,
  });

  /// Whether two-factor authentication is on. A caller who has never set it up
  /// is answered with every flag false rather than with an error, so this is
  /// simply "off" rather than "unknown".
  final bool isActive;

  /// Whether an authenticator application is configured.
  final bool appEnabled;

  /// Whether the emailed-code method is configured.
  final bool emailEnabled;

  /// How many recovery codes are still unused.
  ///
  /// Worth showing plainly: recovery codes are shown once and are the only way
  /// back in when the second factor is unavailable, so running low is
  /// something a person should be told before it matters.
  final int remainingRecoveryCodes;

  /// The methods currently configured, in the order the screen lists them.
  List<TwoFactorMethod> get methods => <TwoFactorMethod>[
    if (appEnabled) TwoFactorMethod.app,
    if (emailEnabled) TwoFactorMethod.email,
  ];
}

/// A second-factor method the API accepts.
///
/// The wire values are the API's own; [label] is what a person reads.
enum TwoFactorMethod {
  app('App', 'Authenticator app'),
  email('Email', 'Emailed code');

  const TwoFactorMethod(this.wireValue, this.label);

  /// What the API calls it in `EnableTwoFactorAuthCommand.methods`.
  final String wireValue;

  final String label;
}

/// What enabling a method produced, and what the confirmation step needs next.
class TwoFactorSetup {
  const TwoFactorSetup({
    required this.method,
    this.otpAuthUri,
    this.emailCodeSent = false,
  });

  final TwoFactorMethod method;

  /// The `otpauth://` URI an authenticator application scans.
  ///
  /// FR-AU-18 renders it as a scannable code and shows the secret as text.
  final String? otpAuthUri;

  /// Whether the API says it sent a code to the person's address.
  final bool emailCodeSent;

  /// The secret inside [otpAuthUri], for typing in by hand.
  ///
  /// AF-09e: a code that will not render must never block setup, and the
  /// secret is what makes that true — so it is pulled out of the URI rather
  /// than left for the reader to find.
  String? get secret {
    final uri = otpAuthUri;

    if (uri == null || uri.isEmpty) {
      return null;
    }

    final secret = Uri.tryParse(uri)?.queryParameters['secret'];

    return (secret == null || secret.isEmpty) ? null : secret;
  }
}
