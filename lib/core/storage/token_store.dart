import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A bearer token together with the moment it stops being valid.
class AuthToken {
  const AuthToken({
    required this.value,
    required this.expiresAt,
    this.viaGoogle = false,
    this.emailVerified = true,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
    value: json['value']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    // Absent in anything written before UI-06, which was password-only.
    viaGoogle: json['viaGoogle'] as bool? ?? false,
    // Absent in anything written before the API reported it. Absent is not
    // evidence of an unverified address, so it reads as verified.
    emailVerified: json['emailVerified'] as bool? ?? true,
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

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  /// The same token with its address now known to be verified, for after the
  /// person has just verified it in this session.
  AuthToken asVerified() => AuthToken(
    value: value,
    expiresAt: expiresAt,
    viaGoogle: viaGoogle,
    emailVerified: true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'value': value,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'viaGoogle': viaGoogle,
    'emailVerified': emailVerified,
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
/// Linux, and WebCrypto-encrypted local storage on the web.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._storage);

  static const String _key = 'heimdall.session.token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthToken?> read() async {
    final raw = await _storage.read(key: _key);

    if (raw == null) {
      return null;
    }

    try {
      return AuthToken.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // A stored value we cannot read is worse than none: drop it rather than
      // failing every launch from here on.
      await clear();

      return null;
    }
  }

  @override
  Future<void> write(AuthToken token) =>
      _storage.write(key: _key, value: jsonEncode(token.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
