import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A bearer token together with the moment it stops being valid.
class AuthToken {
  const AuthToken({
    required this.value,
    required this.expiresAt,
    this.viaGoogle = false,
    this.emailVerified = true,
    this.processingRestricted = false,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
    value: json['value']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    // Absent in anything written before UI-06, which was password-only.
    viaGoogle: json['viaGoogle'] as bool? ?? false,
    // Absent in anything written before the API reported it. Absent is not
    // evidence of an unverified address, so it reads as verified.
    emailVerified: json['emailVerified'] as bool? ?? true,
    // Absent in anything written before UI-30, when no restricted subject
    // could sign in at all.
    processingRestricted: json['processingRestricted'] as bool? ?? false,
  );

  final String value;
  final DateTime expiresAt;

  /// Whether the API considers this person's address verified, as reported
  /// alongside the token it was issued with.
  ///
  /// Stored with the token because a session restored at start-up needs it and
  /// there is nothing to re-read it from until the person endpoint arrives.
  final bool emailVerified;

  /// Whether this session was established through Google.
  ///
  /// Stored rather than inferred because it outlives the exchange: signing out
  /// of a restored session still has to tell Google about it, and nothing in
  /// the token itself says where it came from.
  final bool viaGoogle;

  /// Whether the API said, alongside the token, that processing of this
  /// identity is restricted — and so that the token is a subject-rights-only
  /// one (UI-30).
  ///
  /// The token's own `subjectRightsOnly` claim says the same thing and is what
  /// a restored session is read from; this is kept as well because it is what
  /// the API actually answered at sign-in.
  final bool processingRestricted;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  /// The same token with its address now known to be verified, for after the
  /// person has just verified it in this session.
  AuthToken asVerified() => AuthToken(
    value: value,
    expiresAt: expiresAt,
    viaGoogle: viaGoogle,
    emailVerified: true,
    processingRestricted: processingRestricted,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'value': value,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'viaGoogle': viaGoogle,
    'emailVerified': emailVerified,
    'processingRestricted': processingRestricted,
  };
}

/// Where the session token lives between launches.
///
/// A challenge token is deliberately absent from this interface: it is valid
/// for one endpoint and one attempt, and is never written anywhere.
abstract interface class TokenStore {
  Future<AuthToken?> read();
  Future<void> write(AuthToken token);
  Future<void> clear();
}

/// The store used by tests, which never touches the platform.
class InMemoryTokenStore implements TokenStore {
  AuthToken? _token;

  @override
  Future<AuthToken?> read() async => _token;

  @override
  Future<void> write(AuthToken token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// The production store: Keystore on Android, DPAPI on Windows, libsecret on
/// Linux, and WebCrypto-encrypted session storage on the web.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._storage);

  /// The store the application runs with.
  ///
  /// NFR-04: on the web the token is kept in the tab's session storage, not in
  /// local storage. It goes when the tab is closed, so a shared machine does
  /// not hand it to the next person to open the interface, and no other tab of
  /// the same browser reads it. The browser's storage is readable by any
  /// script on the page, key and ciphertext alike, so the encryption is no
  /// defence on its own; what this buys is a shorter life and a narrower
  /// reach. Every other platform keeps the token in its own secure store.
  const SecureTokenStore.platform()
    : _storage = const FlutterSecureStorage(
        webOptions: WebOptions(useSessionStorage: true),
      );

  static const String _key = 'heimdall.session.token';

  final FlutterSecureStorage _storage;

  /// The platform storage behind this store, for tests to inspect.
  @visibleForTesting
  FlutterSecureStorage get storage => _storage;

  @override
  Future<AuthToken?> read() async {
    final raw = await _storage.read(key: _key);

    if (raw == null) {
      return null;
    }

    try {
      return AuthToken.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // A stored value we cannot read is worse than none: drop it rather than
      // failing every launch from here on. Not only malformed JSON lands here
      // — well-formed JSON of the wrong shape throws a TypeError, which is
      // just as unreadable.
      try {
        await clear();
      } on Object {
        // Dropping it is best-effort; reading it as absent is what matters.
      }

      return null;
    }
  }

  @override
  Future<void> write(AuthToken token) =>
      _storage.write(key: _key, value: jsonEncode(token.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
