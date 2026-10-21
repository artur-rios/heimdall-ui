import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../../applications/presentation/owner_names.dart';
import '../../home/presentation/dashboard_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';
import '../domain/person_repository.dart';

/// How far the person detail has got.
sealed class PersonDetailState {
  const PersonDetailState();
}

/// The record is being read.
final class PersonDetailLoading extends PersonDetailState {
  const PersonDetailLoading();
}

/// AF-18a and AF-18b — the record could not be read.
final class PersonDetailUnavailable extends PersonDetailState {
  const PersonDetailUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The person is gone, and the screen returns to the listing.
final class PersonDeleted extends PersonDetailState {
  const PersonDeleted();
}

/// The record is on screen.
final class PersonDetailLoaded extends PersonDetailState {
  const PersonDetailLoaded(
    this.person, {
    this.saving = false,
    this.saveFailure,
    this.saved = false,
    this.deleting = false,
    this.deleteFailure,
  });

  final Person person;
  final bool saving;
  final Failure? saveFailure;
  final bool saved;

  /// A deletion is on its way. Both controls are disabled while it is.
  final bool deleting;

  /// AF-19b — the API refused to delete, and the person stays open.
  final Failure? deleteFailure;

  /// AF-18d — a logically deleted person is shown, but nothing about them may
  /// be changed from here.
  bool get isReadOnly => person.isDeleted;

  PersonDetailLoaded copyWith({
    Person? person,
    bool? saving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? saved,
    bool? deleting,
    Failure? deleteFailure,
    bool clearDeleteFailure = false,
  }) => PersonDetailLoaded(
    person ?? this.person,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
    deleting: deleting ?? this.deleting,
    deleteFailure: clearDeleteFailure
        ? null
        : (deleteFailure ?? this.deleteFailure),
  );
}

/// Family-keyed on the person's identifier, so two detail screens opened from
/// two tabs do not share one state.
final NotifierProviderFamily<PersonDetailController, PersonDetailState, String>
personDetailControllerProvider =
    NotifierProvider.family<PersonDetailController, PersonDetailState, String>(
      PersonDetailController.new,
    );

/// Owns one person's detail: reading it, and saving edits to it.
class PersonDetailController extends Notifier<PersonDetailState>
    with BuildEpoch<PersonDetailState> {
  PersonDetailController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  @override
  PersonDetailState build() {
    startEpoch();

    return const PersonDetailLoading();
  }

  /// Reads the person.
  ///
  /// Deleted persons are included: AF-18d shows one read-only, and it cannot
  /// do that if the API is asked to pretend they are gone.
  Future<void> load() async {
    // A save or delete in flight owns the state: loading over it would drop
    // its `saving`/`deleting` guard and let its answer overwrite the reread.
    final current = state;

    if (current is PersonDetailLoaded && (current.saving || current.deleting)) {
      return;
    }

    state = const PersonDetailLoading();

    final epoch = this.epoch;
    final result = await ref
        .read(personRepositoryProvider)
        .getById(arg, includeDeleted: true);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    state = result.fold(
      onSuccess: PersonDetailLoaded.new,
      onFailure: PersonDetailUnavailable.new,
    );
  }

  /// Reads the person again without leaving the screen: the record on screen
  /// stays put, with whatever the user is looking at, until the new one
  /// replaces it. A read that fails changes nothing, since the page is still
  /// showing the last record the API confirmed.
  Future<void> refresh() async {
    final epoch = this.epoch;
    final result = await ref
        .read(personRepositoryProvider)
        .getById(arg, includeDeleted: true);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    if (result case Success<Person>(:final value)) {
      final current = state;

      // The flags describe requests that are still in flight or outcomes the
      // user has not yet seen; a reload changes the record, not those.
      state = current is PersonDetailLoaded
          ? current.copyWith(person: value)
          : PersonDetailLoaded(value);
    }
  }

  /// Saves [name] and [email].
  ///
  /// The role is never sent. FR-PE-06 makes this screen's edit the name and
  /// the address, and leaving the role out is also what stops anyone changing
  /// their own (AF-18e).
  Future<void> save({required String name, required String email}) async {
    final current = state;

    if (current is! PersonDetailLoaded ||
        current.saving ||
        current.deleting ||
        current.isReadOnly) {
      return;
    }

    if (name == current.person.name && email == current.person.email) {
      return;
    }

    state = current.copyWith(
      saving: true,
      clearSaveFailure: true,
      saved: false,
    );

    final epoch = this.epoch;
    final result = await ref
        .read(personRepositoryProvider)
        .update(id: arg, name: name, email: email);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    if (result.isSuccess) {
      // The applications list shows owners by name; a rename must reach it.
      ref.read(ownerNamesProvider).forget();
    }

    state = result.fold(
      // The update endpoint does not report a second factor, and this edit
      // cannot have changed one — so the state already read is carried over
      // rather than being replaced by a default.
      onSuccess: (person) => PersonDetailLoaded(
        person.withTwoFactorEnabled(current.person.twoFactorEnabled),
        saved: true,
      ),
      // AF-18c: the refusal is kept as it came back, and the record on screen
      // is still the one the API last confirmed.
      onFailure: (failure) =>
          current.copyWith(saving: false, saveFailure: failure),
    );
  }

  /// Drops the "saved" acknowledgement and any refused save, so a later edit
  /// starts clean.
  void acknowledgeSave() {
    if (state case final PersonDetailLoaded loaded) {
      state = loaded.copyWith(saved: false, clearSaveFailure: true);
    }
  }

  /// Logically deletes the person. The record is hidden, not erased. The API has
  /// no restore: only an operator can undo it, in the database, within the
  /// retention window. The confirmation says so before this is called.
  Future<void> delete() => _delete((repository) => repository.delete(arg));

  /// Permanently deletes the person and everything that belonged to them.
  Future<void> deletePermanently() =>
      _delete((repository) => repository.hardDelete(arg));

  Future<void> _delete(
    Future<Result<void>> Function(PersonRepository repository) send,
  ) async {
    final current = state;

    // One request at a time: each settles on the state it started from.
    if (current is! PersonDetailLoaded || current.deleting || current.saving) {
      return;
    }

    state = current.copyWith(deleting: true, clearDeleteFailure: true);

    final epoch = this.epoch;
    final result = await send(ref.read(personRepositoryProvider));

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (result) {
      case Success<void>():
        ref.markHomeDataStale();
        state = const PersonDeleted();
      case FailureResult<void>(:final failure):
        // Somebody already deleted them, which is the outcome that was asked
        // for. Reporting it as a failure would ask the user to delete a record
        // that no longer exists.
        state = failure.kind == FailureKind.notFound
            ? const PersonDeleted()
            : current.copyWith(deleting: false, deleteFailure: failure);
    }
  }
}
