import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
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
class PersonDetailController extends FamilyNotifier<PersonDetailState, String> {
  @override
  PersonDetailState build(String personId) => const PersonDetailLoading();

  /// Reads the person.
  ///
  /// Deleted persons are included: AF-18d shows one read-only, and it cannot
  /// do that if the API is asked to pretend they are gone.
  Future<void> load() async {
    state = const PersonDetailLoading();

    final result = await ref
        .read(personRepositoryProvider)
        .getById(arg, includeDeleted: true);

    state = result.fold(
      onSuccess: PersonDetailLoaded.new,
      onFailure: PersonDetailUnavailable.new,
    );
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

    final result = await ref
        .read(personRepositoryProvider)
        .update(id: arg, name: name, email: email);

    state = result.fold(
      onSuccess: (person) => PersonDetailLoaded(person, saved: true),
      // AF-18c: the refusal is kept as it came back, and the record on screen
      // is still the one the API last confirmed.
      onFailure: (failure) =>
          current.copyWith(saving: false, saveFailure: failure),
    );
  }

  /// Drops the "saved" acknowledgement so a later edit starts clean.
  void acknowledgeSave() {
    if (state case final PersonDetailLoaded loaded) {
      state = loaded.copyWith(saved: false);
    }
  }

  /// Logically deletes the person. The record is kept and the API can restore
  /// it, which is what the confirmation says before this is called.
  Future<void> delete() => _delete((repository) => repository.delete(arg));

  /// Permanently deletes the person and everything that belonged to them.
  Future<void> deletePermanently() =>
      _delete((repository) => repository.hardDelete(arg));

  Future<void> _delete(
    Future<Result<void>> Function(PersonRepository repository) send,
  ) async {
    final current = state;

    if (current is! PersonDetailLoaded || current.deleting) {
      return;
    }

    state = current.copyWith(deleting: true, clearDeleteFailure: true);

    final result = await send(ref.read(personRepositoryProvider));

    switch (result) {
      case Success<void>():
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
