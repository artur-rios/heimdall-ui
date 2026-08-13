import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';

/// Overridden at start-up with the platform store, and in tests with a fake.
final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider must be overridden'),
);

/// Overridden at start-up with the client-backed implementation.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) =>
          throw UnimplementedError('authRepositoryProvider must be overridden'),
    );

final NotifierProvider<SessionController, SessionState>
sessionControllerProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Reads the principal out of a JWT **without verifying it**.
///
/// The API is the only authority on whether a token is valid; this exists so
/// the interface can show the right navigation. Anything unreadable falls back
/// to the least privileged role, so a malformed token can never widen access.
Principal principalFromToken(AuthToken token) {
  const fallback = Principal(id: '', email: '', role: Role.user);
  final segments = token.value.split('.');

  if (segments.length != 3) {
    return fallback;
  }

  final Map<String, dynamic> payload;

  try {
    payload =
        jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
            )
            as Map<String, dynamic>;
  } on FormatException {
    return fallback;
  }

  final rawRole = payload['role'];

  return Principal(
    id: (payload['sub'] ?? payload['nameid'] ?? '').toString(),
    email: (payload['email'] ?? '').toString(),
    role: switch (rawRole) {
      final int value => roleFromValue(value),
      final String value => roleFromValue(
        int.tryParse(value) ?? Role.user.value,
      ),
      _ => Role.user,
    },
    scopeId: payload['scopeId']?.toString(),
    ownedScopeIds:
        (payload['ownedScopeIds'] as List<dynamic>? ?? const <dynamic>[])
            .map((id) => id.toString())
            .toList(growable: false),
  );
}

/// Owns the session state machine: restoring → unauthenticated → challenged →
/// authenticated.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    unawaited(restore());

    return const SessionRestoring();
  }

  TokenStore get _store => ref.read(tokenStoreProvider);
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Reads the stored token and settles the session. Called once at start-up,
  /// and directly by tests so they need not race the constructor.
  Future<void> restore() async {
    final stored = await _store.read();

    if (stored == null || stored.isExpired) {
      await _store.clear();
      state = const Unauthenticated();

      return;
    }

    state = Authenticated(token: stored, principal: principalFromToken(stored));
  }

  /// Attempts a password login.
  ///
  /// A two-factor challenge is not a failure: it moves the session to
  /// [Challenged] and still returns success, because nothing went wrong.
  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _repository.login(email: email, password: password);

    switch (result) {
      case Success<LoginOutcome>(:final value):
        switch (value) {
          case LoggedIn(:final token):
            await _establish(token);
          case TwoFactorRequired(
            :final challengeToken,
            :final availableMethods,
          ):
            state = Challenged(
              challengeToken: challengeToken,
              availableMethods: availableMethods,
            );
        }

        return const Success<void>(null);
      case FailureResult<LoginOutcome>(:final failure):
        state = const Unauthenticated();

        return FailureResult<void>(failure);
    }
  }

  /// Answers the login challenge. Only valid while the session is [Challenged].
  Future<Result<void>> submitSecondFactor(String code) async {
    final current = state;

    if (current is! Challenged) {
      return const FailureResult<void>(
        Failure(
          kind: FailureKind.unknown,
          errors: <String>['No two-factor challenge is in progress.'],
        ),
      );
    }

    final result = await _repository.verifySecondFactor(
      challengeToken: current.challengeToken,
      code: code,
    );

    switch (result) {
      case Success<AuthToken>(:final value):
        await _establish(value);

        return const Success<void>(null);
      case FailureResult<AuthToken>(:final failure):
        return FailureResult<void>(failure);
    }
  }

  /// Ends the session locally. Called on sign-out and whenever the API rejects
  /// the token with a 401.
  Future<void> signOut() async {
    await _store.clear();
    state = const Unauthenticated();
  }

  Future<void> _establish(AuthToken token) async {
    await _store.write(token);
    state = Authenticated(token: token, principal: principalFromToken(token));
  }
}
