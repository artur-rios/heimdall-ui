import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import '../../persons/domain/person_repository.dart';

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<PersonRepository> personRepositoryProvider =
    Provider<PersonRepository>(
      (ref) => throw UnimplementedError(
        'personRepositoryProvider must be overridden',
      ),
    );

/// How far the profile screen has got.
sealed class ProfileState {
  const ProfileState();
}

/// The record is being read. What the screen shows before anything arrives.
final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// The record could not be read.
///
/// [sessionEnded] marks AF-08e: the API answered `404`, so the person was
/// deleted from under the session and the sign-out has already been started.
final class ProfileUnavailable extends ProfileState {
  const ProfileUnavailable(this.failure, {this.sessionEnded = false});

  final Failure failure;
  final bool sessionEnded;
}

/// The record is on screen.
///
/// [saving] disables the controls while an update is in flight; [saveFailure]
/// carries AF-08b's refusal; [emailChanged] records that the address the API
/// returned differs from the one it held before, which is what AF-08c reacts
/// to.
final class ProfileLoaded extends ProfileState {
  const ProfileLoaded(
    this.person, {
    this.saving = false,
    this.saveFailure,
    this.saved = false,
    this.emailChanged = false,
  });

  final Person person;
  final bool saving;
  final Failure? saveFailure;
  final bool saved;
  final bool emailChanged;

  ProfileLoaded copyWith({
    Person? person,
    bool? saving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? saved,
    bool? emailChanged,
  }) => ProfileLoaded(
    person ?? this.person,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
    emailChanged: emailChanged ?? this.emailChanged,
  );
}

final NotifierProvider<ProfileController, ProfileState>
profileControllerProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);

/// Owns the signed-in person's own record: reading it, and saving edits to it.
class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileLoading();

  PersonRepository get _repository => ref.read(personRepositoryProvider);

  /// Reads the signed-in person's record.
  ///
  /// The identifier comes from the session rather than from a parameter: this
  /// screen is only ever the caller's own profile, and taking an id would make
  /// it look like it could be somebody else's.
  Future<void> load() async {
    final session = ref.read(sessionControllerProvider);

    if (session is! Authenticated) {
      return;
    }

    state = const ProfileLoading();

    final result = await _repository.getById(session.principal.id);

    switch (result) {
      case Success<Person>(:final value):
        state = ProfileLoaded(value);
      case FailureResult<Person>(:final failure):
        await _settleFailure(failure, (f) => ProfileUnavailable(f));
    }
  }

  /// Saves [name] and [email] against the loaded record.
  ///
  /// AF-08d is enforced by the screen, which keeps the control disabled until
  /// something differs; the same comparison is repeated here so a submission
  /// from the keyboard obeys the rule too.
  Future<void> save({required String name, required String email}) async {
    final current = state;

    if (current is! ProfileLoaded || current.saving) {
      return;
    }

    if (name == current.person.name && email == current.person.email) {
      return;
    }

    final previousEmail = current.person.email;
    state = current.copyWith(
      saving: true,
      clearSaveFailure: true,
      saved: false,
    );

    final result = await _repository.update(
      id: current.person.id,
      name: name,
      email: email,
    );

    switch (result) {
      case Success<Person>(:final value):
        state = ProfileLoaded(
          value,
          saved: true,
          // AF-08c: the API marks a changed address unverified again, and the
          // screen offers the resend from UI-05 when it does.
          emailChanged: value.email != previousEmail,
        );
      case FailureResult<Person>(:final failure):
        await _settleFailure(
          failure,
          (f) => current.copyWith(saving: false, saveFailure: f),
        );
    }
  }

  /// Drops the "saved" acknowledgement so a later edit starts clean.
  void acknowledgeSave() {
    if (state case final ProfileLoaded loaded) {
      state = loaded.copyWith(saved: false, emailChanged: false);
    }
  }

  /// AF-08e — a `404` means the person no longer exists, so the session cannot
  /// be honest about who is signed in. Every other failure is reported through
  /// [otherwise] and leaves the session alone.
  Future<void> _settleFailure(
    Failure failure,
    ProfileState Function(Failure failure) otherwise,
  ) async {
    if (failure.kind == FailureKind.notFound) {
      state = ProfileUnavailable(failure, sessionEnded: true);
      // `expired` because the session ended under the caller rather than by
      // their choice, which is what makes the sign-in screen explain itself
      // (AF-07e) instead of just appearing.
      await ref.read(sessionControllerProvider.notifier).signOut(expired: true);

      return;
    }

    state = otherwise(failure);
  }
}
