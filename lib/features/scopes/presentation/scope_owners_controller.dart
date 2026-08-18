import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../persons/domain/person.dart';
import '../../persons/domain/person_repository.dart';
import '../../profile/presentation/profile_controller.dart';

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
/// they are read alongside the owners because the promotion is one of the four
/// things this screen does.
final class ScopeOwnersLoaded extends ScopeOwnersState {
  const ScopeOwnersLoaded({
    required this.owners,
    required this.users,
    this.busy = false,
    this.failure,
  });

  final List<Person> owners;
  final List<Person> users;

  /// A command is on its way. Every control is disabled while it is.
  final bool busy;

  /// The API's refusal of the last command — AF-14a, AF-14b, AF-14c, AF-14d.
  final Failure? failure;

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
    bool? busy,
    Failure? failure,
    bool clearFailure = false,
  }) => ScopeOwnersLoaded(
    owners: owners ?? this.owners,
    users: users ?? this.users,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

final NotifierProviderFamily<ScopeOwnersController, ScopeOwnersState, String>
scopeOwnersControllerProvider =
    NotifierProvider.family<ScopeOwnersController, ScopeOwnersState, String>(
      ScopeOwnersController.new,
    );

/// Owns one scope's owner list and the four things that can be done to it.
class ScopeOwnersController extends FamilyNotifier<ScopeOwnersState, String> {
  @override
  ScopeOwnersState build(String scopeId) => const ScopeOwnersLoading();

  PersonRepository get _repository => ref.read(personRepositoryProvider);

  /// Reads the owners, and the scope's users the promotion draws on.
  ///
  /// The users are not what this screen is about, so a listing that fails does
  /// not take the owners down with it: the promotion is simply not offered.
  Future<void> load() async {
    final owners = await _repository.listScopeOwners(scopeId: arg);

    switch (owners) {
      case FailureResult<Page<Person>>(:final failure):
        state = ScopeOwnersUnavailable(failure);
      case Success<Page<Person>>(:final value):
        final users = await _repository.listScopePersons(scopeId: arg);

        state = ScopeOwnersLoaded(
          owners: value.items,
          users: users.valueOrNull?.items ?? const <Person>[],
        );
    }
  }

  /// Adds a person who is already a Scope Admin as a co-owner.
  Future<void> addOwner(String personId) => _command(
    () => _repository.addScopeOwner(scopeId: arg, personId: personId),
  );

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
  Future<void> createOwner({
    required String name,
    required String email,
    required String password,
  }) => _command(() async {
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
  Future<void> _command(Future<Result<void>> Function() send) async {
    final current = state;

    if (current is! ScopeOwnersLoaded || current.busy) {
      return;
    }

    state = current.copyWith(busy: true, clearFailure: true);

    final result = await send();

    switch (result) {
      case Success<void>():
        await load();
      case FailureResult<void>(:final failure):
        state = current.copyWith(busy: false, failure: failure);
    }
  }
}
