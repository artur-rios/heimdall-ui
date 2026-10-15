import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../../../core/unload/unload_guard.dart';
import '../../auth/domain/two_factor.dart';
import '../../auth/presentation/session_controller.dart';

/// How far the security section has got.
sealed class TwoFactorState {
  const TwoFactorState();
}

/// The configuration is being read.
final class TwoFactorLoading extends TwoFactorState {
  const TwoFactorLoading();
}

/// The configuration could not be read.
///
/// [ineligible] marks the API's permanent refusal: a Google User may never
/// configure a second factor here, which is a fact about the account rather
/// than a fault to retry.
final class TwoFactorUnavailable extends TwoFactorState {
  const TwoFactorUnavailable(this.failure);

  final Failure failure;

  bool get ineligible =>
      failure.kind == FailureKind.forbidden ||
      failure.kind == FailureKind.unauthorized;
}

/// The configuration is on screen, and nothing is part-way through.
final class TwoFactorSettled extends TwoFactorState {
  const TwoFactorSettled(this.status, {this.busy = false, this.failure});

  final TwoFactorStatus status;

  /// A command is on its way; every control is disabled while it is.
  final bool busy;

  /// AF-09d — the API refused the credential, and the feature stays as it was.
  final Failure? failure;

  TwoFactorSettled copyWith({
    TwoFactorStatus? status,
    bool? busy,
    Failure? failure,
    bool clearFailure = false,
  }) => TwoFactorSettled(
    status ?? this.status,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// A method has been started and is waiting for its confirmation code.
///
/// AF-09b: nothing here has been persisted. Leaving the screen discards this
/// state, and two-factor authentication stays off.
final class TwoFactorConfirming extends TwoFactorState {
  const TwoFactorConfirming(
    this.status,
    this.setup, {
    this.busy = false,
    this.failure,
  });

  final TwoFactorStatus status;
  final TwoFactorSetup setup;
  final bool busy;

  /// AF-09a — the code was rejected. The setup stays alive so the person can
  /// try again without starting over.
  final Failure? failure;

  TwoFactorConfirming copyWith({
    bool? busy,
    Failure? failure,
    bool clearFailure = false,
  }) => TwoFactorConfirming(
    status,
    setup,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Recovery codes have been issued and have not been acknowledged.
///
/// AF-09c: the API issues them exactly once, so this state is what the screen
/// refuses to leave until the person says they have them.
final class TwoFactorCodesIssued extends TwoFactorState {
  const TwoFactorCodesIssued(
    this.status,
    this.codes, {
    this.regenerated = false,
  });

  final TwoFactorStatus status;
  final List<String> codes;

  /// Whether these replaced an existing set, which changes what is said about
  /// the codes the person may already have written down.
  final bool regenerated;
}

final NotifierProvider<TwoFactorController, TwoFactorState>
twoFactorControllerProvider =
    NotifierProvider<TwoFactorController, TwoFactorState>(
      TwoFactorController.new,
    );

/// Owns the security section: the configuration, the setup in progress, and
/// the recovery codes that have not been acknowledged.
class TwoFactorController extends Notifier<TwoFactorState>
    with BuildEpoch<TwoFactorState> {
  @override
  TwoFactorState build() {
    startEpoch();

    // AF-09c: closing or reloading the tab is no route change, so while codes
    // wait to be acknowledged the browser is asked to confirm that too. The
    // guard follows the state here, so every way the codes go — acknowledged,
    // left, or dropped with the session — drops it with them.
    final guard = ref.watch(unloadGuardProvider);
    var guarded = false;

    void follow(bool pending) {
      if (pending != guarded) {
        guarded = pending;
        pending ? guard.register() : guard.unregister();
      }
    }

    listenSelf((previous, next) => follow(next is TwoFactorCodesIssued));
    ref.onDispose(() => follow(false));

    return const TwoFactorLoading();
  }

  /// Reads the caller's own configuration.
  Future<void> load() async {
    state = const TwoFactorLoading();

    final epoch = this.epoch;
    final result = await ref.read(authRepositoryProvider).twoFactorStatus();

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    state = result.fold(
      onSuccess: TwoFactorSettled.new,
      onFailure: TwoFactorUnavailable.new,
    );
  }

  /// Starts enabling [method], which moves the screen to its confirmation.
  ///
  /// FR-AU-17: the API asks for the [currentPassword] first. AF-09f: a refusal
  /// is returned rather than kept, for the password dialog to show while it
  /// stays open; the feature stays off and the session untouched. `null` means
  /// the setup started, or that another command was already under way.
  Future<Failure?> beginSetup(
    TwoFactorMethod method, {
    required String currentPassword,
  }) async {
    final current = state;

    if (current is! TwoFactorSettled || current.busy) {
      return null;
    }

    state = current.copyWith(busy: true, clearFailure: true);

    final epoch = this.epoch;
    final result = await ref
        .read(authRepositoryProvider)
        .enableTwoFactor(method, currentPassword: currentPassword);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return result.failureOrNull;
    }

    switch (result) {
      case Success<TwoFactorSetup>(:final value):
        state = TwoFactorConfirming(current.status, value);

        return null;
      case FailureResult<TwoFactorSetup>(:final failure):
        state = current.copyWith(busy: false);

        return failure;
    }
  }

  /// AF-09b — abandons a setup that was never confirmed.
  ///
  /// The pending secret is dropped from memory here; nothing was persisted, so
  /// there is nothing to undo at the API.
  void abandonSetup() {
    if (state case TwoFactorConfirming(:final status)) {
      state = TwoFactorSettled(status);
    }
  }

  /// Confirms the setup with [code].
  ///
  /// AF-09a: a rejection keeps the confirmation alive rather than sending the
  /// person back to the beginning.
  Future<void> confirm(String code) async {
    final current = state;

    if (current is! TwoFactorConfirming || current.busy) {
      return;
    }

    state = current.copyWith(busy: true, clearFailure: true);

    final epoch = this.epoch;
    final result = await ref
        .read(authRepositoryProvider)
        .confirmTwoFactor(method: current.setup.method, code: code);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (result) {
      case Success<List<String>>(:final value):
        // The codes are shown once, so the state that holds them is the one
        // the screen will not leave until they are acknowledged.
        //
        // FR-AU-28: confirming revoked the token that confirmed, so the status
        // is not read back under it — that read would be refused and end the
        // session before the codes were seen. It follows from the command.
        final method = current.setup.method;
        state = TwoFactorCodesIssued(
          TwoFactorStatus(
            isActive: true,
            appEnabled:
                current.status.appEnabled || method == TwoFactorMethod.app,
            emailEnabled:
                current.status.emailEnabled || method == TwoFactorMethod.email,
            remainingRecoveryCodes: value.length,
          ),
          value,
        );
      case FailureResult<List<String>>(:final failure):
        state = current.copyWith(busy: false, failure: failure);
    }
  }

  /// Turns the feature off with the password and the second factor supplied.
  ///
  /// FR-AU-28: a success revokes every token the person holds, this one
  /// included, so they are signed out at once to sign in again.
  Future<void> disable({
    String? password,
    String? code,
    String? recoveryCode,
  }) async {
    final current = state;

    if (current is! TwoFactorSettled || current.busy) {
      return;
    }

    state = current.copyWith(busy: true, clearFailure: true);

    final epoch = this.epoch;
    final result = await ref
        .read(authRepositoryProvider)
        .disableTwoFactor(
          password: password,
          code: code,
          recoveryCode: recoveryCode,
        );

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (result) {
      case Success<void>():
        state = const TwoFactorSettled(TwoFactorStatus());
        await _signOut();
      case FailureResult<void>(:final failure):
        // AF-09d: the credential was refused, and the feature stays on.
        state = current.copyWith(busy: false, failure: failure);
    }
  }

  /// Issues a fresh set of recovery codes, under the same acknowledgement rule
  /// as the first set.
  ///
  /// FR-AU-28: like confirming, a success revokes the token, so the status is
  /// not read back under it.
  Future<void> regenerateRecoveryCodes({
    String? code,
    String? recoveryCode,
  }) async {
    final current = state;

    if (current is! TwoFactorSettled || current.busy) {
      return;
    }

    state = current.copyWith(busy: true, clearFailure: true);

    final epoch = this.epoch;
    final result = await ref
        .read(authRepositoryProvider)
        .regenerateRecoveryCodes(code: code, recoveryCode: recoveryCode);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (result) {
      case Success<List<String>>(:final value):
        final status = current.status;
        state = TwoFactorCodesIssued(
          TwoFactorStatus(
            isActive: status.isActive,
            appEnabled: status.appEnabled,
            emailEnabled: status.emailEnabled,
            remainingRecoveryCodes: value.length,
          ),
          value,
          regenerated: true,
        );
      case FailureResult<List<String>>(:final failure):
        state = current.copyWith(busy: false, failure: failure);
    }
  }

  /// AF-09c — the person says they have the codes, or chose to leave them,
  /// and the screen moves on.
  ///
  /// FR-AU-28: the command that issued them revoked the token, so moving on
  /// is signing out, to sign in again. Nothing happens when no codes are
  /// waiting.
  Future<void> acknowledgeCodes() async {
    if (state case TwoFactorCodesIssued(:final status)) {
      state = TwoFactorSettled(status);
      await _signOut();
    }
  }

  /// Ends the session whose token a change to the second factor revoked, with
  /// the reason the sign-in screen gives.
  Future<void> _signOut() => ref
      .read(sessionControllerProvider.notifier)
      .signOut(credentialsChanged: true);
}
