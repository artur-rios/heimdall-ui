import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/data_rights.dart';
import '../domain/data_rights_repository.dart';

/// Where the restriction dialog is.
class RestrictProcessingState {
  const RestrictProcessingState({
    this.ground,
    this.sending = false,
    this.failure,
  });

  /// The ground the person chose. None is chosen for them: the API asks for
  /// one, and only the person knows which applies.
  final RestrictionGround? ground;

  /// Whether the request is in flight. The dialog cannot be dismissed while
  /// it is, since it is the only place its outcome is shown.
  final bool sending;

  /// Why the last attempt failed, as the API or the transport said it.
  final Failure? failure;

  /// Whether the request may be sent now.
  bool get canConfirm => ground != null && !sending;
}

final NotifierProvider<RestrictProcessingController, RestrictProcessingState>
restrictProcessingControllerProvider =
    NotifierProvider.autoDispose<
      RestrictProcessingController,
      RestrictProcessingState
    >(RestrictProcessingController.new);

/// UI-33 — restricts processing of the signed-in person's own account.
class RestrictProcessingController extends Notifier<RestrictProcessingState> {
  @override
  RestrictProcessingState build() => const RestrictProcessingState();

  /// Records the ground the person chose. Ignored while a request is in
  /// flight, so what is shown is what was sent.
  void choose(RestrictionGround ground) {
    if (state.sending) {
      return;
    }

    state = RestrictProcessingState(ground: ground, failure: state.failure);
  }

  /// Asks the API to restrict processing on the chosen ground, then signs the
  /// person out.
  ///
  /// From the moment the API answers, it refuses the session's token on
  /// everything but the rights endpoints, so the session could do nothing
  /// more: signing in again opens the restricted session (UI-30), and the
  /// sign-in screen says so.
  ///
  /// Any refusal — AF-33b's `409` included — is kept with the API's own
  /// words, and the session stays as it was.
  ///
  /// Answers whether the restriction went through.
  Future<bool> restrict() async {
    final ground = state.ground;

    if (ground == null || state.sending) {
      return false;
    }

    state = RestrictProcessingState(ground: ground, sending: true);

    // Taken before the await: the restriction is real once the API has it,
    // so the session ends whether or not this provider outlives the call.
    final session = ref.read(sessionControllerProvider.notifier);
    final result = await ref
        .read(dataRightsRepositoryProvider)
        .restrictProcessing(ground);

    if (result.failureOrNull case final Failure failure) {
      if (ref.mounted) {
        state = RestrictProcessingState(ground: ground, failure: failure);
      }

      return false;
    }

    await session.signOut(processingRestricted: true);

    return true;
  }
}
