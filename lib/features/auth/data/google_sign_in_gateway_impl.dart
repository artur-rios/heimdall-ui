import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/google_sign_in_gateway.dart';

/// [GoogleSignInGateway] over the `google_sign_in` plugin.
///
/// The only place in the application that knows the plugin exists; everything
/// above it works in terms of [GoogleSignInAttempt].
class PluginGoogleSignInGateway implements GoogleSignInGateway {
  PluginGoogleSignInGateway(this._signIn, this._clientId);

  final GoogleSignIn _signIn;

  /// The client id this build was configured with, which the SDK needs on the
  /// targets that do not read one from a bundled configuration file.
  final String? _clientId;

  /// The plugin requires [GoogleSignIn.initialize] exactly once, before
  /// anything else. It is idempotent here so callers need not track it.
  Future<void>? _initialization;

  @override
  GoogleSignInAvailability get availability {
    // The web SDK answers `supportsAuthenticate()` false and renders its own
    // button instead, which is a different control rather than no control.
    if (kIsWeb) {
      return GoogleSignInAvailability.platformControl;
    }

    try {
      return _signIn.supportsAuthenticate()
          ? GoogleSignInAvailability.interactive
          : GoogleSignInAvailability.unsupported;
    } on Object {
      // AF-06e: Windows and Linux have no implementation to ask, and the
      // platform interface throws rather than answering.
      return GoogleSignInAvailability.unsupported;
    }
  }

  @override
  Future<void> initialize() =>
      _initialization ??= _signIn.initialize(clientId: _clientId);

  @override
  Stream<GoogleIdTokenObtained> get idTokens => _signIn.authenticationEvents
      .where((event) => event is GoogleSignInAuthenticationEventSignIn)
      .map(
        (event) => (event as GoogleSignInAuthenticationEventSignIn)
            .user
            .authentication
            .idToken,
      )
      .where((idToken) => idToken != null)
      .map((idToken) => GoogleIdTokenObtained(idToken!));

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async {
    if (availability != GoogleSignInAvailability.interactive) {
      return const GoogleSignInUnsupported();
    }

    try {
      await initialize();

      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null) {
        return const GoogleSignInUnavailable(
          'Google did not return an ID token.',
        );
      }

      return GoogleIdTokenObtained(idToken);
    } on GoogleSignInException catch (error) {
      // AF-06c: a cancellation is the user changing their mind, not an error.
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => const GoogleSignInCancelled(),
        _ => GoogleSignInUnavailable(
          error.description ?? 'Google sign-in could not be completed.',
        ),
      };
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialization == null) {
      return;
    }

    await _signIn.signOut();
  }
}
