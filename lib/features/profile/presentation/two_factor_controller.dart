import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
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
class TwoFactorController extends Notifier<TwoFactorState> {
  @override
  TwoFactorState build() => const TwoFactorLoading();

  /// Reads the caller's own configuration.
  Future<void> load() async {
    state = const TwoFactorLoading();

    final result = await ref.read(authRepositoryProvider).twoFactorStatus();

    state = result.fold(
      onSuccess: TwoFactorSettled.new,
      onFailure: TwoFactorUnavailable.new,
    );
  }

  /// Starts enabling [method], which moves the screen to its confirmation.
  Future<void> beginSetup(TwoFactorMethod method) async {
    final current = state;

    if (current is! TwoFactorSettled || current.busy) {
      return;
    }

    state = current.copyWith(busy: true, clearFailure: true);

    final result = await ref
        .read(authRepositoryProvider)
        .enableTwoFactor(method);

    state = result.fold(
      onSuccess: (setup) => TwoFactorConfirming(current.status, setup),
      onFailure: (failure) => current.copyWith(busy: false, failure: failure),
    );
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

    final result = await ref
        .read(authRepositoryProvider)
        .confirmTwoFactor(method: current.setup.method, code: code);

    switch (result) {
      case Success<List<String>>(:final value):
        // The codes are shown once, so the state that holds them is the one
        // the screen will not leave until they are acknowledged.
        state = TwoFactorCodesIssued(
          await _reread(fallback: current.status),
          value,
        );
      case FailureResult<List<String>>(:final failure):
        state = current.copyWith(busy: false, failure: failure);
    }
  }

  /// Turns the feature off with whichever credential the person supplied.
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

    final result = await ref
        .read(authRepositoryProvider)
        .disableTwoFactor(
          password: password,
          code: code,
          recoveryCode: recoveryCode,
        );

    switch (result) {
      case Success<void>():
        state = TwoFactorSettled(await _reread(fallback: current.status));
      case FailureResult<void>(:final failure):
        // AF-09d: the credential was refused, and the feature stays on.
        state = current.copyWith(busy: false, failure: failure);
    }
  }

  /// Issues a fresh set of recovery codes, under the same acknowledgement rule
  /// as the first set.
  Future<void> regenerateRecoveryCodes({
    String? code,
    String? recoveryCode,
  }) async {
    final current = state;

    if (current is! TwoFactorSettled || current.busy) {
      return;
    }

    state = current.copyWith(busy: true, clearFailure: true);

    final result = await ref
        .read(authRepositoryProvider)
        .regenerateRecoveryCodes(code: code, recoveryCode: recoveryCode);

    switch (result) {
      case Success<List<String>>(:final value):
        state = TwoFactorCodesIssued(
          await _reread(fallback: current.status),
          value,
          regenerated: true,
        );
      case FailureResult<List<String>>(:final failure):
        state = current.copyWith(busy: false, failure: failure);
    }
  }

  /// AF-09c — the person says they have the codes, and the screen moves on.
  void acknowledgeCodes() {
    if (state case TwoFactorCodesIssued(:final status)) {
      state = TwoFactorSettled(status);
    }
  }

  /// Re-reads the configuration after a command changed it.
  ///
  /// What is shown afterwards should be what the API now holds rather than
  /// what the command implies; [fallback] is used only when the re-read itself
  /// fails, which is better than dropping the screen into an error over a
  /// command that worked.
  Future<TwoFactorStatus> _reread({required TwoFactorStatus fallback}) async {
    final result = await ref.read(authRepositoryProvider).twoFactorStatus();

    return result.valueOrNull ?? fallback;
  }
}
