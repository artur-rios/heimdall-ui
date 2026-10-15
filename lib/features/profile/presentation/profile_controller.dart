import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../auth/domain/session.dart';
import '../../auth/domain/two_factor.dart';
import '../../auth/presentation/session_controller.dart';
import '../../google_users/domain/google_user.dart';
import '../../google_users/domain/google_user_repository.dart';
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
/// [sessionEnded] marks AF-08e: the API answered `404`, so the account was
/// deleted from under the session and the sign-out has already been started.
final class ProfileUnavailable extends ProfileState {
  const ProfileUnavailable(this.failure, {this.sessionEnded = false});

  final Failure failure;
  final bool sessionEnded;
}

/// The record is on screen.
///
/// [saving] disables the controls while an update is in flight; [saveFailure]
/// carries AF-08b's refusal, and AF-08h's.
///
/// [secondFactor] is the person's own two-factor configuration, read once an
/// edit starts and only when the record says it is on (see
/// [ProfileController.readSecondFactor]). It decides what the code an address
/// change asks for (FR-AU-16) is said to be: no emailed code is sent while
/// signed in, so a person whose only method is email answers with a recovery
/// code. It is `null` until read, when the factor is off, or when it could not
/// be read.
final class ProfileLoaded extends ProfileState {
  const ProfileLoaded(
    this.person, {
    this.secondFactor,
    this.saving = false,
    this.saveFailure,
    this.saved = false,
  });

  final Person person;
  final TwoFactorStatus? secondFactor;
  final bool saving;
  final Failure? saveFailure;
  final bool saved;

  ProfileLoaded copyWith({
    Person? person,
    TwoFactorStatus? secondFactor,
    bool? saving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? saved,
  }) => ProfileLoaded(
    person ?? this.person,
    secondFactor: secondFactor ?? this.secondFactor,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
  );
}

/// Whether saving [email] over [person]'s address changes it, as the API
/// decides that: the trimmed values compared exactly, so a change of case
/// alone is a change (FR-AU-16). Only such a change asks for the password,
/// and only it revokes the person's sessions.
bool changesEmail(Person person, String email) =>
    email.trim() != person.email.trim();

/// A Google User's own record is on screen.
///
/// A Google User is not a person: the session's subject is the Google User,
/// read through UC-27 rather than the person endpoint. Every field comes from
/// Google and the API offers no way to change one, so unlike [ProfileLoaded]
/// there is nothing to save.
final class GoogleProfileLoaded extends ProfileState {
  const GoogleProfileLoaded(this.user);

  final GoogleUser user;
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

    if (session.token.viaGoogle) {
      await _loadGoogleUser(session.principal);

      return;
    }

    final result = await _repository.getById(session.principal.id);

    switch (result) {
      case Success<Person>(:final value):
        state = ProfileLoaded(value);
      case FailureResult<Person>(:final failure):
        await _settleFailure(failure, (f) => ProfileUnavailable(f));
    }
  }

  /// Reads the caller's own two-factor configuration into the loaded record,
  /// for the hint beside the code an address change asks for (FR-AU-16).
  ///
  /// Called when an edit starts rather than on [load], which the home screen
  /// runs too and which has no use for it. Asked only when the record says
  /// the factor is on, and only once. A failed read leaves it `null`: it only
  /// shapes a hint, so its absence must not cost the profile.
  Future<void> readSecondFactor() async {
    final current = state;

    if (current is! ProfileLoaded ||
        !current.person.twoFactorEnabled ||
        current.secondFactor != null) {
      return;
    }

    final result = await ref.read(authRepositoryProvider).twoFactorStatus();

    if ((result.valueOrNull, state) case (
      final TwoFactorStatus status,
      final ProfileLoaded latest,
    )) {
      state = latest.copyWith(secondFactor: status);
    }
  }

  /// Reads a Google session's own record.
  ///
  /// A Google sign-in's subject is the Google User, which the person endpoint
  /// does not know, so asking it would answer `404` and end every Google
  /// session (#133). UC-27 lets a Google User read their own record, in the
  /// scope the token names. A `404` here is still AF-08e: the Google User was
  /// deleted from under the session.
  Future<void> _loadGoogleUser(Principal principal) async {
    final scopeId = principal.scopeId;

    if (scopeId == null) {
      // The API always names the scope of a Google User; a token that does
      // not is unreadable rather than evidence the account is gone, so the
      // session is left alone.
      state = const ProfileUnavailable(
        Failure(
          kind: FailureKind.unknown,
          errors: <String>[],
          message: 'This session does not say which scope it belongs to.',
        ),
      );

      return;
    }

    final result = await ref
        .read(googleUserRepositoryProvider)
        .getById(scopeId: scopeId, id: principal.id, includeDeleted: false);

    switch (result) {
      case Success<GoogleUser>(:final value):
        state = GoogleProfileLoaded(value);
      case FailureResult<GoogleUser>(:final failure):
        await _settleFailure(failure, (f) => ProfileUnavailable(f));
    }
  }

  /// Saves [name] and [email] against the loaded record.
  ///
  /// AF-08d is enforced by the screen, which keeps the control disabled until
  /// something differs; the same comparison is repeated here so a submission
  /// from the keyboard obeys the rule too.
  ///
  /// FR-AU-16: a new address travels with [currentPassword], and with
  /// [twoFactorCode] when the second factor is on. Nothing else does: a
  /// name-only edit sends neither, whatever was typed.
  ///
  /// FR-AU-28: a new address revokes every token the person holds, the one
  /// that saved it included, so a successful change signs them out to sign in
  /// again with it. The address is unverified by then, which the sign-in
  /// that follows reports (AF-05e).
  Future<void> save({
    required String name,
    required String email,
    String? currentPassword,
    String? twoFactorCode,
  }) async {
    final current = state;

    if (current is! ProfileLoaded || current.saving) {
      return;
    }

    if (name == current.person.name && email == current.person.email) {
      return;
    }

    final reauthenticates = changesEmail(current.person, email);
    state = current.copyWith(
      saving: true,
      clearSaveFailure: true,
      saved: false,
    );

    final result = await _repository.update(
      id: current.person.id,
      name: name,
      email: email,
      currentPassword: reauthenticates ? currentPassword : null,
      twoFactorCode: reauthenticates && current.person.twoFactorEnabled
          ? twoFactorCode
          : null,
    );

    switch (result) {
      case Success<Person>(:final value):
        state = ProfileLoaded(
          // The update endpoint does not report a second factor, and this edit
          // cannot have changed one — so the state already read carries over.
          value.withTwoFactorEnabled(current.person.twoFactorEnabled),
          secondFactor: current.secondFactor,
          saved: true,
        );

        if (reauthenticates) {
          await ref
              .read(sessionControllerProvider.notifier)
              .signOut(credentialsChanged: true);
        }
      case FailureResult<Person>(:final failure):
        await _settleFailure(
          failure,
          (f) => current.copyWith(saving: false, saveFailure: f),
        );
    }
  }

  /// Drops the "saved" acknowledgement and any refused save, so a later edit
  /// starts clean.
  void acknowledgeSave() {
    if (state case final ProfileLoaded loaded) {
      state = loaded.copyWith(saved: false, clearSaveFailure: true);
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
