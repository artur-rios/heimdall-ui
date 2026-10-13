import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../domain/email_link.dart';
import '../domain/scope.dart';
import '../domain/scope_repository.dart';
import 'scope_list_controller.dart';

/// Which of UI-31's three writes is outstanding.
enum SignInSettingsAction { googleSignIn, selfRegistration, emailLinks }

/// How far UI-31's screen has got.
sealed class SignInSettingsState {
  const SignInSettingsState();
}

/// The scope is being read.
final class SignInSettingsLoading extends SignInSettingsState {
  const SignInSettingsLoading();
}

/// AF-31a and AF-31h — the scope could not be read.
final class SignInSettingsUnavailable extends SignInSettingsState {
  const SignInSettingsUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The scope's settings are on screen.
final class SignInSettingsLoaded extends SignInSettingsState {
  const SignInSettingsLoaded(
    this.scope, {
    this.inFlight,
    this.googleSignInFailure,
    this.selfRegistrationFailure,
    this.linksFailure,
    this.linksSaved = false,
  });

  final Scope scope;

  /// The write on its way, if any. One at a time: each settles on the state
  /// it started from, so a second in flight would be overwritten by whichever
  /// answered last.
  final SignInSettingsAction? inFlight;

  /// AF-15a / AF-31c — the API refused the Google Sign-In toggle.
  final Failure? googleSignInFailure;

  /// AF-31c — the API refused the self-registration toggle.
  final Failure? selfRegistrationFailure;

  /// AF-31d — the API refused the links.
  final Failure? linksFailure;

  /// The links were saved; the card shows the saved notice.
  final bool linksSaved;

  bool get isBusy => inFlight != null;

  /// AF-31b — a logically deleted scope is shown, and nothing changes it.
  bool get isReadOnly => scope.isDeleted;
}

final NotifierProviderFamily<
  ScopeSignInSettingsController,
  SignInSettingsState,
  String
>
scopeSignInSettingsControllerProvider =
    NotifierProvider.family<
      ScopeSignInSettingsController,
      SignInSettingsState,
      String
    >(ScopeSignInSettingsController.new);

/// UI-31 — one scope's ways in: Google Sign-In, self-registration, and the
/// links its emails point at.
class ScopeSignInSettingsController extends Notifier<SignInSettingsState> {
  ScopeSignInSettingsController(this.arg);

  /// The scope's identifier.
  final String arg;

  @override
  SignInSettingsState build() => const SignInSettingsLoading();

  Future<void> load() async {
    state = const SignInSettingsLoading();

    final result = await ref.read(scopeRepositoryProvider).getById(arg);

    state = result.fold(
      onSuccess: SignInSettingsLoaded.new,
      onFailure: SignInSettingsUnavailable.new,
    );
  }

  /// UI-15, now on this screen. The toggle's output carries neither the
  /// privacy settings nor self-registration, so both are kept from the scope
  /// already known rather than read as cleared.
  Future<void> setGoogleSignIn(bool enabled) => _write(
    SignInSettingsAction.googleSignIn,
    (repository) => repository.setGoogleSignIn(id: arg, enabled: enabled),
    merge: (answer, known) =>
        answer.withPrivacySettingsOf(known).withSelfRegistrationOf(known),
  );

  /// Opens or closes self-registration. The screen asks first (AF-31f,
  /// AF-31g); by the time this runs the person has agreed.
  Future<void> setSelfRegistration(bool enabled) => _write(
    SignInSettingsAction.selfRegistration,
    (repository) => repository.setSelfRegistration(id: arg, enabled: enabled),
    merge: (answer, known) => answer.withPrivacySettingsOf(known),
  );

  /// Saves both links, trimmed, with an empty one sent as `null` (a clear).
  /// Nothing is sent when neither differs from what the API holds.
  Future<void> saveEmailLinks({
    required String? emailVerificationUrl,
    required String? passwordResetUrl,
  }) async {
    final current = state;
    final verification = normalizeEmailLink(emailVerificationUrl);
    final reset = normalizeEmailLink(passwordResetUrl);

    if (current is SignInSettingsLoaded &&
        verification == current.scope.emailVerificationUrl &&
        reset == current.scope.passwordResetUrl) {
      return;
    }

    await _write(
      SignInSettingsAction.emailLinks,
      (repository) => repository.setEmailLinks(
        id: arg,
        emailVerificationUrl: verification,
        passwordResetUrl: reset,
      ),
      merge: (answer, known) => answer.withPrivacySettingsOf(known),
    );
  }

  /// Drops the saved notice and any refused save, so a later edit starts
  /// clean.
  void acknowledgeLinks() {
    if (state case final SignInSettingsLoaded loaded) {
      state = SignInSettingsLoaded(
        loaded.scope,
        inFlight: loaded.inFlight,
        googleSignInFailure: loaded.googleSignInFailure,
        selfRegistrationFailure: loaded.selfRegistrationFailure,
      );
    }
  }

  Future<void> _write(
    SignInSettingsAction action,
    Future<Result<Scope>> Function(ScopeRepository repository) send, {
    required Scope Function(Scope answer, Scope known) merge,
  }) async {
    final current = state;

    if (current is! SignInSettingsLoaded ||
        current.isBusy ||
        current.isReadOnly) {
      return;
    }

    // A new write clears the refusal it would replace; the others stay.
    state = SignInSettingsLoaded(
      current.scope,
      inFlight: action,
      googleSignInFailure: action == SignInSettingsAction.googleSignIn
          ? null
          : current.googleSignInFailure,
      selfRegistrationFailure: action == SignInSettingsAction.selfRegistration
          ? null
          : current.selfRegistrationFailure,
      linksFailure: action == SignInSettingsAction.emailLinks
          ? null
          : current.linksFailure,
    );

    final result = await send(ref.read(scopeRepositoryProvider));

    state = result.fold(
      onSuccess: (answer) => SignInSettingsLoaded(
        merge(answer, current.scope),
        googleSignInFailure: action == SignInSettingsAction.googleSignIn
            ? null
            : current.googleSignInFailure,
        selfRegistrationFailure: action == SignInSettingsAction.selfRegistration
            ? null
            : current.selfRegistrationFailure,
        linksFailure: action == SignInSettingsAction.emailLinks
            ? null
            : current.linksFailure,
        linksSaved: action == SignInSettingsAction.emailLinks,
      ),
      // The scope on screen stays the one the API last confirmed.
      onFailure: (failure) => SignInSettingsLoaded(
        current.scope,
        googleSignInFailure: action == SignInSettingsAction.googleSignIn
            ? failure
            : current.googleSignInFailure,
        selfRegistrationFailure: action == SignInSettingsAction.selfRegistration
            ? failure
            : current.selfRegistrationFailure,
        linksFailure: action == SignInSettingsAction.emailLinks
            ? failure
            : current.linksFailure,
      ),
    );
  }
}
