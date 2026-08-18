import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../auth/domain/session.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';

/// How far a create attempt has got.
sealed class PersonCreateState {
  const PersonCreateState();
}

/// The form is being filled in.
final class PersonCreateEditing extends PersonCreateState {
  const PersonCreateEditing();
}

/// A request is in flight. The form refuses a second submission in this state,
/// so a double tap cannot create two people.
final class PersonCreateSending extends PersonCreateState {
  const PersonCreateSending();
}

/// The person exists, and their verification email is on its way.
final class PersonCreated extends PersonCreateState {
  const PersonCreated(this.person);

  final Person person;
}

/// AF-17b, AF-17c, AF-17d — the API refused. The form keeps everything typed.
final class PersonCreateRejected extends PersonCreateState {
  const PersonCreateRejected(this.failure);

  final Failure failure;
}

final NotifierProviderFamily<PersonCreateController, PersonCreateState, String>
personCreateControllerProvider =
    NotifierProvider.family<PersonCreateController, PersonCreateState, String>(
      PersonCreateController.new,
    );

/// Owns one create attempt from filled in to created.
class PersonCreateController extends FamilyNotifier<PersonCreateState, String> {
  @override
  PersonCreateState build(String scopeId) => const PersonCreateEditing();

  /// Creates the person.
  ///
  /// The chosen [role] decides which endpoint answers: a User belongs to the
  /// scope, while a Scope Admin or System Admin belongs to none and is created
  /// through the unscoped endpoint the API reserves for a System Admin.
  Future<void> create({
    required String name,
    required String email,
    required String password,
    required Role role,
  }) async {
    if (state is PersonCreateSending) {
      return;
    }

    state = const PersonCreateSending();

    final repository = ref.read(personRepositoryProvider);
    final result = role == Role.user
        ? await repository.createUser(
            scopeId: arg,
            name: name,
            email: email,
            password: password,
          )
        : await repository.createAdmin(
            name: name,
            email: email,
            password: password,
            role: role,
          );

    state = result.fold(
      onSuccess: PersonCreated.new,
      onFailure: PersonCreateRejected.new,
    );
  }
}

/// The roles a [principal] may create.
///
/// AF-17d: a Scope Admin may not create a System Admin — nor, since the
/// unscoped endpoint is a System Admin's alone, a Scope Admin. They create
/// users of their scope, which is what they are offered.
List<Role> creatableRolesFor(Principal principal) => principal.isSystemAdmin
    ? const <Role>[Role.user, Role.scopeAdmin, Role.systemAdmin]
    : const <Role>[Role.user];
