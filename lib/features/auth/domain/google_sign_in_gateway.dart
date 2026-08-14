/// How — or whether — Google's flow can be run on this target.
enum GoogleSignInAvailability {
  /// The application offers its own control and drives the flow from it.
  interactive,

  /// Google renders the control itself and reports the result out of band.
  /// The web is like this: its SDK refuses to be driven from an arbitrary
  /// widget, so the button on screen is Google's own.
  platformControl,

  /// AF-06e — the flow cannot be run here at all.
  unsupported,
}

/// What asking Google to identify the user produced.
sealed class GoogleSignInAttempt {
  const GoogleSignInAttempt();
}

/// Google identified the user and issued an ID token for the API to exchange.
final class GoogleIdTokenObtained extends GoogleSignInAttempt {
  const GoogleIdTokenObtained(this.idToken);

  final String idToken;
}

/// AF-06c — the user backed out of Google's own flow. Nothing was sent and
/// nothing should change; this is not a failure to put in front of them.
final class GoogleSignInCancelled extends GoogleSignInAttempt {
  const GoogleSignInCancelled();
}

/// AF-06e — this target cannot run the flow.
final class GoogleSignInUnsupported extends GoogleSignInAttempt {
  const GoogleSignInUnsupported();
}

/// Google refused, or its SDK is misconfigured. Distinct from a rejection by
/// Heimdall, which never reaches this type.
final class GoogleSignInUnavailable extends GoogleSignInAttempt {
  const GoogleSignInUnavailable(this.message);

  final String message;
}

/// Google's half of UI-06, behind an interface so that the session controller
/// and the sign-in screen never see the plugin — and so every flow above can be
/// tested without Google's SDK.
abstract interface class GoogleSignInGateway {
  GoogleSignInAvailability get availability;

  /// Prepares the SDK. Required before anything else, and safe to call twice.
  Future<void> initialize();

  /// Runs the flow from the application's own control.
  /// Only meaningful when [availability] is
  /// [GoogleSignInAvailability.interactive].
  Future<GoogleSignInAttempt> obtainIdToken();

  /// ID tokens arriving from a control Google rendered itself.
  /// Only meaningful when [availability] is
  /// [GoogleSignInAvailability.platformControl].
  Stream<GoogleIdTokenObtained> get idTokens;

  /// Ends the local Google session. Safe to call when there is none.
  Future<void> signOut();
}
