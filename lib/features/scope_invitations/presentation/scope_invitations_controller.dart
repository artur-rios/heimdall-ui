import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../../scopes/presentation/scope_list_controller.dart';
import '../domain/scope_invitation.dart';
import '../domain/scope_invitation_repository.dart';

/// How far the signed-in administrator's invitations have got (UI-39).
sealed class ScopeInvitationsState {
  const ScopeInvitationsState();
}

/// Nothing has been read yet.
final class ScopeInvitationsLoading extends ScopeInvitationsState {
  const ScopeInvitationsLoading();
}

/// The invitations could not be read (AF-39e). Home shows no card for them.
final class ScopeInvitationsUnavailable extends ScopeInvitationsState {
  const ScopeInvitationsUnavailable(this.failure);

  final Failure failure;
}

/// The invitations are known.
final class ScopeInvitationsLoaded extends ScopeInvitationsState {
  const ScopeInvitationsLoaded({
    required this.invitations,
    this.busy = false,
    this.notice,
    this.failure,
  });

  final List<ScopeInvitation> invitations;

  /// An answer is on its way. Every control is disabled while it is.
  final bool busy;

  /// What the last answer did: "Invitation accepted. …" or "Invitation
  /// declined."
  final String? notice;

  /// The API's refusal of the last answer — AF-39c, AF-39d.
  final Failure? failure;

  /// Whether Home has anything to show: an invitation, or the outcome of the
  /// last answer even when that emptied the list.
  bool get isVisible =>
      invitations.isNotEmpty || notice != null || failure != null;
}

final NotifierProvider<ScopeInvitationsController, ScopeInvitationsState>
scopeInvitationsControllerProvider =
    NotifierProvider<ScopeInvitationsController, ScopeInvitationsState>(
      ScopeInvitationsController.new,
    );

/// Owns the signed-in administrator's open scope owner invitations and their
/// two answers (UI-39).
class ScopeInvitationsController extends Notifier<ScopeInvitationsState>
    with BuildEpoch<ScopeInvitationsState> {
  @override
  ScopeInvitationsState build() {
    startEpoch();

    return const ScopeInvitationsLoading();
  }

  ScopeInvitationRepository get _repository =>
      ref.read(scopeInvitationRepositoryProvider);

  /// Reads the invitations.
  Future<void> load() async {
    final epoch = this.epoch;
    final result = await guardUnexpected(() => _repository.listMine());

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    state = result.fold<ScopeInvitationsState>(
      onSuccess: (page) => ScopeInvitationsLoaded(invitations: page.items),
      onFailure: ScopeInvitationsUnavailable.new,
    );
  }

  /// Accepts [invitation], which makes the caller an owner of its scope.
  /// Answers whether it went through.
  Future<bool> accept(ScopeInvitation invitation) => _answer(
    () => _repository.accept(invitation.id),
    notice: 'Invitation accepted. You now co-own ${invitation.scopeName}.',
    grantsOwnership: true,
  );

  /// Declines [invitation]. Answers whether it went through.
  Future<bool> decline(ScopeInvitation invitation) => _answer(
    () => _repository.decline(invitation.id),
    notice: 'Invitation declined.',
  );

  /// Sends one answer and reads the invitations again, so what is on screen is
  /// what the API last confirmed.
  ///
  /// AF-39c: a `404` means the invitation ended meanwhile — withdrawn, expired,
  /// or answered elsewhere — so the list is read again and the API's words
  /// shown. AF-39d: any other refusal keeps the list as it was.
  Future<bool> _answer(
    Future<Result<void>> Function() send, {
    required String notice,
    bool grantsOwnership = false,
  }) async {
    final current = state;

    if (current is! ScopeInvitationsLoaded || current.busy) {
      return false;
    }

    final epoch = this.epoch;
    state = ScopeInvitationsLoaded(
      invitations: current.invitations,
      busy: true,
    );

    final result = await send();

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return false;
    }

    final failure = result.failureOrNull;

    if (failure != null && failure.kind != FailureKind.notFound) {
      state = ScopeInvitationsLoaded(
        invitations: current.invitations,
        failure: failure,
      );

      return false;
    }

    if (failure == null && grantsOwnership) {
      // The scope is the caller's now: the scope list must not keep its old
      // answer.
      ref.invalidate(scopeListControllerProvider);
    }

    await load();

    if (!isCurrent(epoch)) {
      return false;
    }

    if (state case final ScopeInvitationsLoaded loaded) {
      state = ScopeInvitationsLoaded(
        invitations: loaded.invitations,
        notice: failure == null ? notice : null,
        failure: failure,
      );
    }

    return failure == null;
  }
}
