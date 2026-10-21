import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_saver.dart';
import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../../auth/domain/google_sign_in_gateway.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/data_rights.dart';
import '../domain/data_rights_repository.dart';

/// Which of the restricted session's actions is in flight.
enum RestrictedSessionAction { lifting, exporting, erasing }

/// What the restricted session screen knows.
class RestrictedSessionState {
  const RestrictedSessionState({
    this.busy,
    this.failure,
    this.exported = false,
    this.exportedTo,
    this.erasure,
  });

  /// The action in flight, if any. Every control is disabled while one is, so
  /// a second tap cannot send a second request.
  final RestrictedSessionAction? busy;

  /// Why the last action failed, as the API or the platform said it.
  final Failure? failure;

  /// Whether a copy of the person's data was saved in this session.
  final bool exported;

  /// Where it was saved, or `null` when the browser took it as a download.
  final String? exportedTo;

  /// What the erasure request recorded, once one was made.
  final ErasureRequest? erasure;

  RestrictedSessionState copyWith({
    RestrictedSessionAction? busy,
    bool clearBusy = false,
    Failure? failure,
    bool clearFailure = false,
    bool? exported,
    String? exportedTo,
    ErasureRequest? erasure,
  }) => RestrictedSessionState(
    busy: clearBusy ? null : (busy ?? this.busy),
    failure: clearFailure ? null : (failure ?? this.failure),
    exported: exported ?? this.exported,
    exportedTo: exportedTo ?? this.exportedTo,
    erasure: erasure ?? this.erasure,
  );
}

final NotifierProvider<RestrictedSessionController, RestrictedSessionState>
restrictedSessionControllerProvider =
    NotifierProvider<RestrictedSessionController, RestrictedSessionState>(
      RestrictedSessionController.new,
    );

/// UI-30 — the four things a subject-rights-only session can do.
class RestrictedSessionController extends Notifier<RestrictedSessionState>
    with BuildEpoch<RestrictedSessionState> {
  @override
  RestrictedSessionState build() {
    startEpoch();
    // What one session saved or requested is no business of the next one's,
    // which may be somebody else's on the same device. A request still in
    // flight belongs to the session that made it, so its answer is dropped.
    ref.listen(sessionControllerProvider, (previous, next) {
      if (next is! Authenticated) {
        advanceEpoch();
        state = const RestrictedSessionState();
      }
    });

    return const RestrictedSessionState();
  }

  DataRightsRepository get _repository =>
      ref.read(dataRightsRepositoryProvider);

  /// Lifts the restriction, then signs the person out.
  ///
  /// The token that lifted it stays confined to the rights endpoints, so the
  /// session could do nothing more with it: signing in again is what brings
  /// full access back, and the sign-in screen says so.
  ///
  /// AF-30b: a restriction already lifted elsewhere — on another device, or
  /// by a System Admin — answers `404`. The outcome the person wanted holds
  /// all the same, so it ends the same way.
  Future<void> liftRestriction() async {
    if (!_start(RestrictedSessionAction.lifting)) {
      return;
    }

    final epoch = this.epoch;
    final result = await _repository.liftOwnRestriction();

    // The session ended since it was asked: the answer is that session's.
    if (!isCurrent(epoch)) {
      return;
    }

    if (result.failureOrNull case final Failure failure
        when failure.kind != FailureKind.notFound) {
      state = state.copyWith(clearBusy: true, failure: failure);

      return;
    }

    await ref
        .read(sessionControllerProvider.notifier)
        .signOut(restrictionLifted: true);
  }

  /// Fetches a copy of everything held about the person and saves it.
  Future<void> exportData() async {
    if (!_start(RestrictedSessionAction.exporting)) {
      return;
    }

    final epoch = this.epoch;
    final result = await _repository.exportMyData();

    // The session ended since it was asked: the answer is that session's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (result) {
      case FailureResult<DataExport>(:final failure):
        state = state.copyWith(clearBusy: true, failure: failure);
      case Success<DataExport>(:final value):
        try {
          final savedTo = await ref
              .read(fileSaverProvider)
              .saveText(fileName: value.fileName, contents: value.document);

          // The session ended since it was asked: the answer is that session's.
          if (!isCurrent(epoch)) {
            return;
          }

          state = RestrictedSessionState(
            exported: true,
            exportedTo: savedTo,
            erasure: state.erasure,
          );
        } on Object catch (error) {
          if (!isCurrent(epoch)) {
            return;
          }

          // AF-30d: the API answered, but the device would not keep the file.
          state = state.copyWith(
            clearBusy: true,
            failure: Failure(
              kind: FailureKind.unknown,
              errors: <String>['Your data could not be saved: $error'],
            ),
          );
        }
    }
  }

  /// Asks for the person's identity to be erased, confirmed with [credential].
  Future<void> requestErasure(ErasureCredential credential) async {
    if (!_start(RestrictedSessionAction.erasing)) {
      return;
    }

    await _erase(credential);
  }

  /// Sends the erasure request for a flow [_start] has already marked busy.
  Future<void> _erase(ErasureCredential credential) async {
    final epoch = this.epoch;
    final result = await _repository.requestErasure(credential);

    // The session ended since it was asked: the answer is that session's.
    if (!isCurrent(epoch)) {
      return;
    }

    state = switch (result) {
      Success<ErasureRequest>(:final value) => RestrictedSessionState(
        exported: state.exported,
        exportedTo: state.exportedTo,
        erasure: value,
      ),
      FailureResult<ErasureRequest>(:final failure) => state.copyWith(
        clearBusy: true,
        failure: failure,
      ),
    };
  }

  /// Asks Google for a fresh ID token, then requests erasure with it — on a
  /// target where the application drives Google's flow itself.
  ///
  /// A cancelled flow changes nothing: nothing was sent.
  Future<void> requestErasureWithGoogle() async {
    // Marked busy before Google is asked, so a second tap while its flow is
    // open is ignored rather than opening another.
    if (!_start(RestrictedSessionAction.erasing)) {
      return;
    }

    final epoch = this.epoch;
    final attempt = await ref.read(googleSignInGatewayProvider).obtainIdToken();

    // The session ended since it was asked: the answer is that session's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (attempt) {
      case GoogleIdTokenObtained(:final idToken):
        await _erase(GoogleIdTokenCredential(idToken));
      case GoogleSignInCancelled():
        state = state.copyWith(clearBusy: true);
      case GoogleSignInUnsupported():
        state = state.copyWith(
          clearBusy: true,
          failure: const Failure(
            kind: FailureKind.unknown,
            errors: <String>[
              'Google sign-in is not available on this device, so erasure '
                  'cannot be confirmed here.',
            ],
          ),
        );
      case GoogleSignInUnavailable(:final message):
        state = state.copyWith(
          clearBusy: true,
          failure: Failure(
            kind: FailureKind.unknown,
            errors: <String>[message],
          ),
        );
    }
  }

  /// Ends the session, as anywhere else.
  Future<void> signOut() =>
      ref.read(sessionControllerProvider.notifier).signOut();

  /// Marks [action] as in flight, unless another one already is.
  bool _start(RestrictedSessionAction action) {
    if (state.busy != null) {
      return false;
    }

    state = state.copyWith(busy: action, clearFailure: true);

    return true;
  }
}
