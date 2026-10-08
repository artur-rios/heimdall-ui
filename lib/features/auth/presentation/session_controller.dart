import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../core/scope/scope_source.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/google_sign_in_gateway.dart';
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

/// Overridden at start-up with the plugin-backed gateway, and in tests with a
/// fake, so no test ever reaches Google.
final Provider<GoogleSignInGateway> googleSignInGatewayProvider =
    Provider<GoogleSignInGateway>(
      (ref) => throw UnimplementedError(
        'googleSignInGatewayProvider must be overridden',
      ),
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
///
/// The claims are the API's own (`IdentityUserMapper`): `id` and `role`, plus
/// `scopeId` for a User and `ownedScopeIds` — one comma-separated string — for
/// a Scope Admin. Every value is written as a string.
Principal principalFromToken(AuthToken token) {
  const fallback = Principal(id: '', email: '', role: Role.user);
  final segments = token.value.split('.');

  if (segments.length != 3) {
    return fallback;
  }

  final Object? decoded;

  try {
    decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
    );
  } on FormatException {
    return fallback;
  }

  if (decoded is! Map<String, dynamic>) {
    return fallback;
  }

  final payload = decoded;
  final rawRole = payload['role'];
  final scopeId = payload['scopeId']?.toString();

  return Principal(
    id: (payload['id'] ?? payload['sub'] ?? payload['nameid'] ?? '').toString(),
    email: (payload['email'] ?? '').toString(),
    name: (payload['name'] ?? '').toString(),
    role: switch (rawRole) {
      final int value => roleFromValue(value),
      final String value => roleFromValue(
        int.tryParse(value) ?? Role.user.value,
      ),
      _ => Role.user,
    },
    scopeId: (scopeId == null || scopeId.isEmpty) ? null : scopeId,
    ownedScopeIds: _idsFrom(payload['ownedScopeIds']),
    // AF-05e: not a claim. The API reports it alongside the token it issues,
    // and that answer travels on [AuthToken] rather than inside the JWT.
    emailVerified: token.emailVerified,
  );
}

/// Reads a list-valued claim, which the API writes as one comma-separated
/// string. An array is accepted as well; anything else is no ids at all.
List<String> _idsFrom(Object? claim) => switch (claim) {
  final String joined =>
    joined
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false),
  final List<dynamic> ids =>
    ids.map((id) => id.toString()).toList(growable: false),
  _ => const <String>[],
};

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
  GoogleSignInGateway get _google => ref.read(googleSignInGatewayProvider);

  /// Reads the stored token and settles the session. Called once at start-up,
  /// and directly by tests so they need not race the constructor.
  Future<void> restore() async {
    final AuthToken? stored;

    try {
      stored = await _store.read();
    } on Object {
      // A store the platform cannot read — a locked keyring, a key lost to a
      // backup restore — must not hold start-up on the restoring screen for
      // ever. There is no session to restore, which is the honest answer.
      state = const Unauthenticated();

      return;
    }

    if (stored == null || stored.isExpired) {
      await _clearStore();
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
            return _establish(token);
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

  /// Runs Google's flow from the application's own control, then exchanges
  /// what it produced.
  ///
  /// AF-06c: a cancellation is a success carrying no change — nothing was
  /// sent, so there is nothing to report and nothing to undo.
  Future<Result<void>> signInWithGoogle() async {
    final attempt = await _google.obtainIdToken();

    return switch (attempt) {
      GoogleIdTokenObtained(:final idToken) => await exchangeGoogleIdToken(
        idToken,
      ),
      GoogleSignInCancelled() => const Success<void>(null),
      GoogleSignInUnsupported() => const FailureResult<void>(
        Failure(
          kind: FailureKind.unknown,
          errors: <String>['Google sign-in is not available on this device.'],
        ),
      ),
      GoogleSignInUnavailable(:final message) => FailureResult<void>(
        Failure(kind: FailureKind.unknown, errors: <String>[message]),
      ),
    };
  }

  /// Exchanges a Google ID token for a Heimdall session.
  ///
  /// Separate from [signInWithGoogle] because on the web the token arrives
  /// from a control Google rendered itself, with no call of ours to await.
  ///
  /// The scope comes from the calling application, which is the only party that
  /// knows which one is being entered.
  Future<Result<void>> exchangeGoogleIdToken(String idToken) async {
    final result = await _repository.signInWithGoogle(
      idToken: idToken,
      scopeId: ref.read(scopeSourceProvider).read(),
    );

    switch (result) {
      case Success<AuthToken>(:final value):
        return _establish(value);
      case FailureResult<AuthToken>(:final failure):
        // AF-06b and AF-06d: Heimdall refused, but Google still considers the
        // user signed in. Dropping that leaves the next attempt to start from
        // the account chooser rather than silently reusing the refused one.
        await _google.signOut();
        state = const Unauthenticated();

        return FailureResult<void>(failure);
    }
  }

  /// Records that the signed-in person's address is now verified.
  ///
  /// AF-05e: the API reported the address as unverified when it issued this
  /// token, and verifying it in this session does not issue a new one. Without
  /// this the prompt would go on nagging about something already done.
  Future<void> markEmailVerified() async {
    if (state case Authenticated(:final token) when !token.emailVerified) {
      final verified = token.asVerified();
      await _store.write(verified);
      state = Authenticated(
        token: verified,
        principal: principalFromToken(verified),
      );
    }
  }

  /// Remembers which of the offered methods the user is answering with.
  ///
  /// AF-02c: the choice belongs to the challenge, not to the screen, so it
  /// outlives a rebuild and is gone the moment the challenge is.
  void chooseMethod(String method) {
    if (state case final Challenged current
        when current.availableMethods.contains(method)) {
      state = current.withMethod(method);
    }
  }

  /// Drops the challenge and returns the session to unauthenticated.
  ///
  /// AF-02e: leaving the screen ends the challenge. The token was never
  /// persisted, so there is nothing to clear beyond the state itself.
  void abandonChallenge() {
    if (state is Challenged) {
      state = const Unauthenticated();
    }
  }

  /// Answers the login challenge. Only valid while the session is [Challenged].
  ///
  /// A rejection keeps the challenge alive (AF-02a); a challenge the API no
  /// longer recognises ends it (AF-02b), which sends the user back to sign in.
  Future<Result<void>> submitSecondFactor(
    String code, {
    bool isRecoveryCode = false,
  }) async {
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
      isRecoveryCode: isRecoveryCode,
    );

    switch (result) {
      case Success<AuthToken>(:final value):
        return _establish(value);
      case FailureResult<AuthToken>(:final failure):
        if (_endsTheChallenge(failure.kind) && state is Challenged) {
          state = const Unauthenticated();
        }

        return FailureResult<void>(failure);
    }
  }

  /// Whether a failure means the challenge itself is gone rather than the code
  /// being wrong. The envelope carries no code of its own for this, so the
  /// status is the signal: a challenge the API will not accept from anyone
  /// again cannot be retried on this screen.
  static bool _endsTheChallenge(FailureKind kind) => switch (kind) {
    FailureKind.unauthorized ||
    FailureKind.forbidden ||
    FailureKind.notFound => true,
    _ => false,
  };

  /// Ends the session. Called on sign-out and whenever the API rejects the
  /// token with a 401.
  ///
  /// A Google session is ended at the API and at Google as well as here. Both
  /// are best-effort: a refusal from either must not leave the user signed in
  /// locally, which is the part this side actually controls.
  ///
  /// AF-07e: [expired] marks a session that ended under the caller rather than
  /// one they chose to leave, so the sign-in screen can say which happened.
  /// The API has already refused that token, so it is not sent back to the
  /// API's sign-out — which would refuse it again.
  ///
  /// A sign-out already under way is not started twice. Its own call to the
  /// API can come back 401, and that 401 reaches here again through the
  /// interceptor; without this it would sign out again, call again, and so on.
  Future<void> signOut({bool expired = false}) async {
    if (_signingOut) {
      return;
    }

    _signingOut = true;

    try {
      if (state case Authenticated(:final token) when token.viaGoogle) {
        if (!expired && !token.isExpired) {
          await _repository.signOutFromGoogle();
        }

        await _google.signOut();
      }

      await _clearStore();
      state = Unauthenticated(sessionExpired: expired);
    } finally {
      _signingOut = false;
    }
  }

  bool _signingOut = false;

  /// Drops the stored token. Best-effort: a store the platform will not touch
  /// must not keep the person signed in here, which is the part this side
  /// controls — the token it holds is one the next start-up cannot read anyway.
  Future<void> _clearStore() async {
    try {
      await _store.clear();
    } on Object {
      // Nothing more to do; the session below ends regardless.
    }
  }

  /// Stores [token] and makes it the session.
  ///
  /// Every request reads its bearer token back from the store, so a token the
  /// platform refused to keep is no session at all: it is reported rather than
  /// left to fail every request after this one — or, thrown, to leave the
  /// screen that asked spinning for good.
  Future<Result<void>> _establish(AuthToken token) async {
    try {
      await _store.write(token);
    } on Object {
      state = const Unauthenticated();

      return const FailureResult<void>(_storeUnavailable);
    }

    state = Authenticated(token: token, principal: principalFromToken(token));

    return const Success<void>(null);
  }
}

/// The platform's secure storage refused the session token — on Linux, most
/// often because no Secret Service keyring is running or it is locked.
const Failure _storeUnavailable = Failure(
  kind: FailureKind.unknown,
  errors: <String>[
    'This device could not store your session securely, so you were not '
        'signed in. Check that its keyring or secure storage is available, '
        'then try again.',
  ],
);
