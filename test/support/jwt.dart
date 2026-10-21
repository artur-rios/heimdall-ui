import 'dart:convert';

import 'package:heimdall_ui/core/storage/token_store.dart';

/// A token naming a signed-in person, for tests that hold a session.
///
/// Only the payload is read by the application, so the header and signature are
/// placeholders. A claim given as `null` is left out: the application reads an
/// absent claim differently from an empty one. [role] is a number or, as the
/// API mints it, a string. [extra] adds or overrides any other claim.
String testJwt({
  Object? role = 1,
  String? sub = 'person-1',
  String? email = 'admin@example.com',
  String? name,
  String? scopeId,
  String? ownedScopeIds,
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'sub': ?sub,
        'email': ?email,
        'name': ?name,
        'role': ?role,
        'scopeId': ?scopeId,
        'ownedScopeIds': ?ownedScopeIds,
        ...extra,
      }),
    ),
  );

  return 'header.$payload.signature';
}

/// A token shaped exactly as the API mints one (`IdentityUserMapper`): a real
/// header, unpadded segments and an `exp`, with [claims] as given, so a test can
/// name `id` and string `role` claims, comma-separated owned scopes, or the
/// claim that restricts a session.
String testApiJwt(Map<String, Object?> claims) {
  String segment(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  return '${segment(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'})}.'
      '${segment(<String, Object?>{...claims, 'exp': 1893456000})}.'
      'signature';
}

/// The stored token for [jwt], which stays valid well past any test.
AuthToken testToken(
  String jwt, {
  bool viaGoogle = false,
  bool emailVerified = true,
  bool processingRestricted = false,
}) => AuthToken(
  value: jwt,
  expiresAt: DateTime.utc(2030),
  viaGoogle: viaGoogle,
  emailVerified: emailVerified,
  processingRestricted: processingRestricted,
);
