import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../../persons/domain/person.dart';
import '../../persons/domain/person_repository.dart';
import '../../persons/presentation/scope_members.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../scope_invitations/domain/scope_invitation.dart';
import '../../scope_invitations/domain/scope_invitation_repository.dart';

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
/// [users] are the scope's User persons, which is what the promotion offers;
/// [invitations] are the people asked to co-own it who have not answered yet.
/// Both are read alongside the owners because the screen acts on them.
final class ScopeOwnersLoaded extends ScopeOwnersState {
  const ScopeOwnersLoaded({
    required this.owners,
    required this.users,
    this.invitations = const <OwnerInvitation>[],
    this.busy = false,
    this.failure,
    this.notice,
  });

  final List<Person> owners;
  final List<Person> users;

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

  /// AF-14a — a scope with one owner cannot lose it, so the control does not
  /// offer to. The API refuses regardless; this is what stops the interface
  /// promising otherwise.
  bool get canRemove => owners.length > 1;

  /// AF-14c — someone who already owns the scope is not offered again.
  Set<String> get ownerIds => owners.map((owner) => owner.id).toSet();

  /// The users who could be promoted: the scope's users, minus anyone already
  /// owning it.
  List<Person> get promotable => users
      .where((user) => !ownerIds.contains(user.id))
      .toList(growable: false);

  ScopeOwnersLoaded copyWith({
    List<Person>? owners,
    List<Person>? users,
    List<OwnerInvitation>? invitations,
    bool? busy,
    Failure? failure,
    bool clearFailure = false,
    String? notice,
    bool clearNotice = false,
  }) => ScopeOwnersLoaded(
    owners: owners ?? this.owners,
    users: users ?? this.users,
    invitations: invitations ?? this.invitations,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : (failure ?? this.failure),
    notice: clearNotice ? null : (notice ?? this.notice),
  );
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

  /// Reads the owners, and the scope's users the promotion draws on.
  ///
  /// The users are not what this screen is about, so a listing that fails does
  /// not take the owners down with it: the promotion is simply not offered.
  Future<void> load() async {
    final epoch = this.epoch;
    final owners = await _repository.listScopeOwners(scopeId: arg);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (owners) {
      case FailureResult<Page<Person>>(:final failure):
        state = ScopeOwnersUnavailable(failure);
      case Success<Page<Person>>(:final value):
        final users = await _repository.listScopePersons(scopeId: arg);

        // Reset since it was asked: the answer is an earlier build's.
        if (!isCurrent(epoch)) {
          return;
        }

        // Like the users, the pending invitations do not decide whether the
        // owners can be shown: a listing that fails shows none.
        final invitations = await _invitations.listForScope(arg);

        // Reset since it was asked: the answer is an earlier build's.
        if (!isCurrent(epoch)) {
          return;
        }

        state = ScopeOwnersLoaded(
          owners: value.items,
          users: users.valueOrNull?.items ?? const <Person>[],
          invitations:
              invitations.valueOrNull?.items ?? const <OwnerInvitation>[],
        );
    }
  }

  /// Adds a person who is already a Scope Admin as a co-owner — or, when the
  /// caller is a Scope Admin, invites them (FR-SC-14) and says so: they are then
  /// listed under the pending invitations, not among the owners (AF-14h).
  Future<void> addOwner(String personId) async {
    final epoch = this.epoch;
    AddOwnerOutcome? outcome;

    await _command(() async {
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
      return;
    }

    if (state case final ScopeOwnersLoaded loaded) {
      state = loaded.copyWith(notice: 'Invitation sent');
    }
  }

  /// Withdraws an open invitation (UC-58).
  ///
  /// AF-14g: one that already ended — another owner withdrew it, the person
  /// answered, or it ran out — comes back as not found. The list is read again,
  /// so it disappears, and the API's words say why.
  Future<void> withdraw(OwnerInvitation invitation) async {
    final epoch = this.epoch;
    final failure = await _command(
      () => _invitations.withdraw(arg, invitation.id),
    );

    if (failure?.kind != FailureKind.notFound || !isCurrent(epoch)) {
      return;
    }

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
  Future<void> promote(String personId) => _command(
    () => _repository.promoteScopeUser(scopeId: arg, personId: personId),
  );

  /// Creates a brand-new Scope Admin directly as a co-owner.
  ///
  /// Answers with the API's refusal, or `null` once the owner exists. The
  /// refusal is the dialog's to show, beside what was typed, so it is not also
  /// put on the screen behind it.
  Future<Failure?> createOwner({
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
  /// Answers with the refusal, if there was one. [reportFailure] decides
  /// whether the screen shows it too.
  Future<Failure?> _command(
    Future<Result<void>> Function() send, {
    bool reportFailure = true,
  }) async {
    final current = state;

    if (current is! ScopeOwnersLoaded || current.busy) {
      return null;
    }

    state = current.copyWith(busy: true, clearFailure: true, clearNotice: true);

    final epoch = this.epoch;
    final result = await send();

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return result.failureOrNull;
    }

    switch (result) {
      case Success<void>():
        // The owners are who an application may be given to, so the
        // selector that offers them must not keep the old list.
        ref.invalidate(scopeMembersProvider(arg));
        await load();

        return null;
      case FailureResult<void>(:final failure):
        state = reportFailure
            ? current.copyWith(busy: false, failure: failure, clearNotice: true)
            : current.copyWith(busy: false, clearNotice: true);

        return failure;
    }
  }
}
