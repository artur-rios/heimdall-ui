import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
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

/// How the session's expiry timer is made. A seam for tests, which run it on
/// a fake clock.
final Provider<Timer Function(Duration, void Function())>
sessionExpiryTimerProvider =
    Provider<Timer Function(Duration, void Function())>((ref) => Timer.new);

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
///
/// UI-30: a subject-rights-only token says so in its `subjectRightsOnly`
/// claim. The sign-in response says it too, and either is enough: a token
/// that claims to admit only the rights endpoints is treated as one even when
/// nothing else about it can be read, since the cost of being wrong that way
/// is one screen, and the other way is every screen failing with `403`.
Principal principalFromToken(AuthToken token) {
  final fallback = Principal(
    id: '',
    email: '',
    role: Role.user,
    subjectRightsOnly: token.processingRestricted,
  );
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
    subjectRightsOnly:
        token.processingRestricted || _isTrue(payload['subjectRightsOnly']),
  );
}

/// Reads a flag claim, which the API writes as the string `"true"`. A JSON
/// boolean is accepted as well; anything else is false.
bool _isTrue(Object? claim) => switch (claim) {
  final bool value => value,
  final String value => value.toLowerCase() == 'true',
  _ => false,
};

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
    // #182: the session ends at its token's expiry rather than at the next
    // request that finds it refused. Following the state here, beside it,
    // means every way a session begins, is replaced or ends — sign-in,
    // restore, a verified address, sign-out — moves the timer with it.
    listenSelf((previous, next) {
      _expiry?.cancel();
      _expiry = null;

      if (next is Authenticated) {
        _armExpiry(next.token);
      }
    });
    ref.onDispose(() => _expiry?.cancel());

    unawaited(restore());

    return const SessionRestoring();
  }

  Timer? _expiry;

  /// The longest a single timer is armed for. Browsers keep a timer's delay
  /// in 32 bits and fire at once past 2^31-1 ms (about 24 days), so a token
  /// that lives longer is waited for in steps.
  static const Duration _longestWait = Duration(days: 7);

  /// Ends the session as expired when [token] runs out; at once if it already
  /// has, which a token handed over just as it lapsed can be.
  void _armExpiry(AuthToken token) => _armFor(
    token,
    token.expiresAt.toUtc().difference(DateTime.now().toUtc()),
  );

  void _armFor(AuthToken token, Duration remaining) {
    final wait = remaining <= Duration.zero
        ? Duration.zero
        : (remaining > _longestWait ? _longestWait : remaining);

    // An expiry already past is not acted on inside the state change that
    // announced it.
    _expiry = ref.read(sessionExpiryTimerProvider)(wait, () {
      // Only for the token it was armed for: a session replaced meanwhile has
      // a timer of its own.
      if (state case Authenticated(token: final current)
          when identical(current, token)) {
        if (remaining > _longestWait) {
          _armFor(token, remaining - _longestWait);
        } else {
          unawaited(signOut(expired: true));
        }
      }
    });
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
    // The scope comes from the calling application, as it does for Google.
    final result = await _repository.login(
      email: email,
      password: password,
      scopeId: ref.read(scopeSourceProvider).read(),
    );

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
  ///
  /// An answer the client cannot read is a failure like any other, returned
  /// rather than thrown, so the control that asked can say so and stop.
  Future<Result<void>> exchangeGoogleIdToken(String idToken) async {
    final result = await guardUnexpected(
      () => _repository.signInWithGoogle(
        idToken: idToken,
        scopeId: ref.read(scopeSourceProvider).read(),
      ),
    );

    switch (result) {
      case Success<AuthToken>(:final value):
        return _establish(value);
      case FailureResult<AuthToken>(:final failure):
        // AF-06b and AF-06d: Heimdall refused, but Google still considers the
        // user signed in. Dropping that leaves the next attempt to start from
        // the account chooser rather than silently reusing the refused one.
        // Best-effort: the refusal is what the caller is waiting to hear, and
        // a Google sign-out that throws must not replace it.
        await _bestEffort(_google.signOut);
        state = const Unauthenticated();

        return FailureResult<void>(failure);
    }
  }

  /// Records that the signed-in person's address is now verified.
  ///
  /// AF-05e: the API reported the address as unverified when it issued this
  /// token, and verifying it in this session does not issue a new one. Without
  /// this the prompt would go on nagging about something already done.
  ///
  /// The session can end, or be replaced, while the store is written. The write
  /// then must neither revive the session nor leave its token stored, so the
  /// store is put back to whatever session is current by then.
  Future<void> markEmailVerified() async {
    if (state case Authenticated(:final token) when !token.emailVerified) {
      final verified = token.asVerified();
      await _store.write(verified);

      switch (state) {
        case Authenticated(token: final current) when identical(current, token):
          state = Authenticated(
            token: verified,
            principal: principalFromToken(verified),
          );
        case Authenticated(token: final current):
          await _bestEffort(() => _store.write(current));
        case _:
          await _clearStore();
      }
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

  /// UI-02 — a new email code for the challenge this session holds. The
  /// challenge is not changed: the API never extends or reissues it.
  Future<Result<void>> resendSecondFactorCode() async {
    final current = state;

    if (current is! Challenged) {
      return const FailureResult<void>(
        Failure(
          kind: FailureKind.unknown,
          errors: <String>['There is no sign-in to send a code for.'],
        ),
      );
    }

    return _repository.resendSecondFactorCode(
      challengeToken: current.challengeToken,
    );
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
  /// are best-effort: a refusal from either, or a throw, must not leave the
  /// user signed in locally, which is the part this side actually controls.
  /// The stored token and the session here go whatever those calls do.
  ///
  /// AF-07e: [expired] marks a session that ended under the caller rather than
  /// one they chose to leave, so the sign-in screen can say which happened.
  /// The API has already refused that token, so it is not sent back to the
  /// API's sign-out — which would refuse it again.
  ///
  /// A sign-out already under way is not started twice. Its own call to the
  /// API can come back 401, and that 401 reaches here again through the
  /// interceptor; without this it would sign out again, call again, and so on.
  ///
  /// UI-30: [restrictionLifted] marks a sign-out that follows lifting a
  /// restriction on processing, so the sign-in screen can say why. A
  /// subject-rights-only token is not sent to the API's Google sign-out
  /// either: that endpoint is not one of the four such a token is admitted to,
  /// so the call could only come back `403`.
  ///
  /// UI-33: [processingRestricted] marks a sign-out that follows restricting
  /// processing of the person's own account. From then on the API refuses the
  /// token everywhere but the rights endpoints, its Google sign-out included,
  /// so that is not called either.
  ///
  /// UI-08, UI-09: [credentialsChanged] marks a sign-out that follows a change
  /// to the person's own sign-in details — their email address, or their
  /// second factor. The API has revoked every token they hold, this one
  /// included, so nothing is sent under it.
  Future<void> signOut({
    bool expired = false,
    bool restrictionLifted = false,
    bool processingRestricted = false,
    bool credentialsChanged = false,
  }) async {
    if (_signingOut) {
      return;
    }

    _signingOut = true;

    try {
      if (state case Authenticated(:final token, :final principal)
          when token.viaGoogle) {
        if (!expired &&
            !processingRestricted &&
            !credentialsChanged &&
            !token.isExpired &&
            !principal.subjectRightsOnly) {
          await _bestEffort(_repository.signOutFromGoogle);
        }

        await _bestEffort(_google.signOut);
      }
    } finally {
      // Neither of these throws: the store is cleared best-effort too.
      await _clearStore();
      state = Unauthenticated(
        sessionExpired: expired,
        restrictionLifted: restrictionLifted,
        processingRestricted: processingRestricted,
        credentialsChanged: credentialsChanged,
      );
      _signingOut = false;
    }
  }

  bool _signingOut = false;

  /// How long ending a session waits on the API, on Google, or on the
  /// platform's store before going on without it.
  static const Duration _externalCallTimeout = Duration(seconds: 5);

  /// Makes a call to the API or to Google whose failure, of whatever kind,
  /// must not stop what follows it — nor its silence: one that has not
  /// answered within [_externalCallTimeout] is given up on.
  static Future<void> _bestEffort(Future<Object?> Function() call) async {
    try {
      await call().timeout(_externalCallTimeout);
    } on Object {
      // Best-effort by design; the caller goes on regardless.
    }
  }

  /// Drops the stored token. Best-effort: a store the platform will not touch
  /// must not keep the person signed in here, which is the part this side
  /// controls — the token it holds is one the next start-up cannot read anyway.
  Future<void> _clearStore() async {
    try {
      await _store.clear().timeout(_externalCallTimeout);
    } on Object {
      // Nothing more to do; the session below ends regardless.
    }
  }

  /// Stores [token] and makes it the session.
  ///
  /// A token the platform refused to keep is no session at all — it would be
  /// gone at the next start-up, and the store could not be relied on to clear
  /// it at sign-out either — so it is reported rather than used, and never
  /// thrown, which would leave the screen that asked spinning for good.
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
