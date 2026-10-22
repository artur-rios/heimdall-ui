import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../../home/presentation/dashboard_controller.dart';
import '../../persons/domain/person.dart';
import '../../persons/domain/person_repository.dart';
import '../../persons/presentation/scope_members.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../scope_invitations/domain/scope_invitation.dart';
import '../../scope_invitations/domain/scope_invitation_repository.dart';
import 'scope_users_controller.dart';

/// How far the owners section has got.
sealed class ScopeOwnersState {
  const ScopeOwnersState();
}

/// The owners are being read.
final class ScopeOwnersLoading extends ScopeOwnersState {
  const ScopeOwnersLoading();
}

/// The owners could not be read.
final class ScopeOwnersUnavailable extends ScopeOwnersState {
  const ScopeOwnersUnavailable(this.failure);

  final Failure failure;
}

/// The owners are on screen.
///
/// [ownersPage] is the page of owners being shown, whose paging metadata says
/// how many the scope has in all; [invitations] are the people asked to co-own
/// it who have not answered yet. They are read alongside the owners because the
/// screen acts on them. The users the promotion offers are a listing of their
/// own (`scopeUsersControllerProvider`).
final class ScopeOwnersLoaded extends ScopeOwnersState {
  const ScopeOwnersLoaded({
    required this.ownersPage,
    this.invitations = const <OwnerInvitation>[],
    this.busy = false,
    this.failure,
    this.notice,
  });

  final Page<Person> ownersPage;

  /// The scope's open owner invitations (UC-58). The people in it own nothing
  /// until they accept.
  final List<OwnerInvitation> invitations;

  /// A command is on its way. Every control is disabled while it is.
  final bool busy;

  /// The API's refusal of the last command — AF-14a, AF-14b, AF-14c, AF-14d,
  /// AF-14g.
  final Failure? failure;

  /// What the last command did when the lists alone would not say it:
  /// "Invitation sent" after a Scope Admin's add (AF-14h).
  final String? notice;

  /// The owners on the page being shown.
  List<Person> get owners => ownersPage.items;

  /// How many owners the scope has in all, as the API counts them — not how
  /// many are on this page (#159).
  int get ownerCount => ownersPage.totalItems;

  /// AF-14a — a scope with one owner cannot lose it, so the control does not
  /// offer to. The API refuses regardless; this is what stops the interface
  /// promising otherwise. It counts every owner, because the page shown may
  /// hold only one of many.
  bool get canRemove => ownerCount > 1;

  /// AF-14c — someone who already owns the scope is not offered again. Only the
  /// owners on this page are known here; the users the promotion lists are
  /// never owners (a User owns no scope, FR-SC-08), so this is a safeguard.
  Set<String> get ownerIds => owners.map((owner) => owner.id).toSet();

  ScopeOwnersLoaded copyWith({
    Page<Person>? ownersPage,
    List<OwnerInvitation>? invitations,
    bool? busy,
    Failure? failure,
    bool clearFailure = false,
    String? notice,
    bool clearNotice = false,
  }) => ScopeOwnersLoaded(
    ownersPage: ownersPage ?? this.ownersPage,
    invitations: invitations ?? this.invitations,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : (failure ?? this.failure),
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

/// What a command did, so a command that was ignored is told apart from one
/// the API accepted.
sealed class OwnerCommandResult {
  const OwnerCommandResult();
}

/// The API accepted the command.
final class OwnerCommandDone extends OwnerCommandResult {
  const OwnerCommandDone();
}

/// The API refused the command, in its own words.
final class OwnerCommandRefused extends OwnerCommandResult {
  const OwnerCommandRefused(this.failure);

  final Failure failure;
}

/// The command never left the app: the owners were still loading, or another
/// command was on its way. Nothing was created, changed, or removed.
final class OwnerCommandNotSent extends OwnerCommandResult {
  const OwnerCommandNotSent();
}

final NotifierProviderFamily<ScopeOwnersController, ScopeOwnersState, String>
scopeOwnersControllerProvider =
    NotifierProvider.family<ScopeOwnersController, ScopeOwnersState, String>(
      ScopeOwnersController.new,
    );

/// Owns one scope's owner list, its pending invitations, and the five things
/// that can be done to them.
class ScopeOwnersController extends Notifier<ScopeOwnersState>
    with BuildEpoch<ScopeOwnersState> {
  ScopeOwnersController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  @override
  ScopeOwnersState build() {
    startEpoch();

    return const ScopeOwnersLoading();
  }

  PersonRepository get _repository => ref.read(personRepositoryProvider);

  ScopeInvitationRepository get _invitations =>
      ref.read(scopeInvitationRepositoryProvider);

  /// Reads the owners — the page already shown, or the first — and the open
  /// invitations.
  Future<void> load() async {
    final epoch = this.epoch;
    final shown = state;
    final owners = await _readOwners(
      shown is ScopeOwnersLoaded ? shown.ownersPage.pageNumber : 1,
    );

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (owners) {
      case FailureResult<Page<Person>>(:final failure):
        state = ScopeOwnersUnavailable(failure);
      case Success<Page<Person>>(:final value):
        // The pending invitations do not decide whether the owners can be
        // shown: a listing that fails shows none.
        final invitations = await _invitations.listForScope(arg);

        // Reset since it was asked: the answer is an earlier build's.
        if (!isCurrent(epoch)) {
          return;
        }

        state = ScopeOwnersLoaded(
          ownersPage: value,
          invitations:
              invitations.valueOrNull?.items ?? const <OwnerInvitation>[],
        );
    }
  }

  /// Reads one page of owners. A page past the end — the last owner of the
  /// last page was removed — would show nobody and no pager to leave by, so the
  /// last page that still exists is read instead.
  Future<Result<Page<Person>>> _readOwners(int pageNumber) async {
    final result = await _repository.listScopeOwners(
      scopeId: arg,
      pageNumber: pageNumber,
    );

    if (result case Success<Page<Person>>(:final value)
        when value.items.isEmpty && pageNumber > 1) {
      return _repository.listScopeOwners(
        scopeId: arg,
        pageNumber: value.totalPages.clamp(1, pageNumber - 1),
      );
    }

    return result;
  }

  /// Shows another page of the owners.
  ///
  /// The page on screen stays while it is read, and a page that cannot be read
  /// leaves it in place with the failure beside it, rather than replacing the
  /// screen: the owners are still there to act on.
  Future<void> goToOwnersPage(int pageNumber) async {
    final current = state;

    if (current is! ScopeOwnersLoaded || current.busy) {
      return;
    }

    state = current.copyWith(busy: true, clearFailure: true, clearNotice: true);

    final epoch = this.epoch;
    final result = await _readOwners(pageNumber);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    state = switch (result) {
      Success<Page<Person>>(:final value) => current.copyWith(
        ownersPage: value,
        busy: false,
        clearFailure: true,
        clearNotice: true,
      ),
      FailureResult<Page<Person>>(:final failure) => current.copyWith(
        busy: false,
        failure: failure,
        clearNotice: true,
      ),
    };
  }

  /// Adds a person who is already a Scope Admin as a co-owner — or, when the
  /// caller is a Scope Admin, invites them (FR-SC-14) and says so: they are then
  /// listed under the pending invitations, not among the owners (AF-14h).
  ///
  /// Answers with what became of the add, so the screen can say when it was
  /// never sent (#165).
  Future<OwnerCommandResult> addOwner(String personId) async {
    final epoch = this.epoch;
    AddOwnerOutcome? outcome;

    final result = await _command(() async {
      final result = await _repository.addScopeOwner(
        scopeId: arg,
        personId: personId,
      );
      outcome = result.valueOrNull;

      return result.fold(
        onSuccess: (_) => const Success<void>(null),
        onFailure: FailureResult<void>.new,
      );
    });

    if (!isCurrent(epoch) || outcome != AddOwnerOutcome.invited) {
      return result;
    }

    if (state case final ScopeOwnersLoaded loaded) {
      state = loaded.copyWith(notice: 'Invitation sent');
    }

    return result;
  }

  /// Withdraws an open invitation (UC-58).
  ///
  /// AF-14g: one that already ended — another owner withdrew it, the person
  /// answered, or it ran out — comes back as not found. The list is read again,
  /// so it disappears, and the API's words say why.
  Future<void> withdraw(OwnerInvitation invitation) async {
    final epoch = this.epoch;
    final outcome = await _command(
      () => _invitations.withdraw(arg, invitation.id),
    );

    if (outcome is! OwnerCommandRefused ||
        outcome.failure.kind != FailureKind.notFound ||
        !isCurrent(epoch)) {
      return;
    }

    final failure = outcome.failure;

    await load();

    if (!isCurrent(epoch)) {
      return;
    }

    if (state case final ScopeOwnersLoaded loaded) {
      state = loaded.copyWith(failure: failure);
    }
  }

  /// Removes an owner.
  ///
  /// AF-14f: the caller removing themselves is warned by the screen before
  /// this is reached; afterwards the reload is what shows them the scope is no
  /// longer theirs.
  Future<void> removeOwner(String personId) => _command(
    () => _repository.removeScopeOwner(scopeId: arg, personId: personId),
  );

  /// Promotes a User of the scope to Scope Admin and co-owner.
  ///
  /// The user is a Scope Admin from then on, so the list they were offered in
  /// is read again, on the page and search it was showing.
  Future<OwnerCommandResult> promote(String personId) async {
    final epoch = this.epoch;
    final result = await _command(
      () => _repository.promoteScopeUser(scopeId: arg, personId: personId),
    );

    if (result is OwnerCommandDone && isCurrent(epoch)) {
      await ref.read(scopeUsersControllerProvider(arg).notifier).load();
    }

    return result;
  }

  /// Creates a brand-new Scope Admin directly as a co-owner.
  ///
  /// Answers with what became of the draft: created, refused by the API, or
  /// never sent because the screen was not ready for a command. The refusal is
  /// the dialog's to show, beside what was typed, so it is not also put on the
  /// screen behind it.
  Future<OwnerCommandResult> createOwner({
    required String name,
    required String email,
    required String password,
  }) => _command(reportFailure: false, () async {
    final created = await _repository.createScopeOwner(
      scopeId: arg,
      name: name,
      email: email,
      password: password,
    );

    return created.fold(
      onSuccess: (_) => const Success<void>(null),
      onFailure: FailureResult<void>.new,
    );
  });

  /// Runs one command and reloads, so what is on screen is always what the API
  /// last confirmed rather than a guess about what the command did.
  ///
  /// Answers with the refusal, if there was one, or that nothing was sent.
  /// [reportFailure] decides whether the screen shows a refusal too.
  Future<OwnerCommandResult> _command(
    Future<Result<void>> Function() send, {
    bool reportFailure = true,
  }) async {
    final current = state;

    if (current is! ScopeOwnersLoaded || current.busy) {
      return const OwnerCommandNotSent();
    }

    state = current.copyWith(busy: true, clearFailure: true, clearNotice: true);

    final epoch = this.epoch;
    final result = await send();

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return _outcome(result);
    }

    switch (result) {
      case Success<void>():
        ref.markHomeDataStale();
        // The owners are who an application may be given to, so the
        // selector that offers them must not keep the old list.
        ref.invalidate(scopeMembersProvider(arg));
        await load();

        return const OwnerCommandDone();
      case FailureResult<void>(:final failure):
        state = reportFailure
            ? current.copyWith(busy: false, failure: failure, clearNotice: true)
            : current.copyWith(busy: false, clearNotice: true);

        return OwnerCommandRefused(failure);
    }
  }

  OwnerCommandResult _outcome(Result<void> result) => switch (result) {
    FailureResult<void>(:final failure) => OwnerCommandRefused(failure),
    Success<void>() => const OwnerCommandDone(),
  };
}
