import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/scope_permission.dart';
import '../domain/scope_permission_repository.dart';

/// How far a create attempt has got.
sealed class PermissionCreateState {
  const PermissionCreateState();
}

/// The form is being filled in.
final class PermissionCreateEditing extends PermissionCreateState {
  const PermissionCreateEditing();
}

/// A request is in flight. The form refuses a second submission in this state.
final class PermissionCreateSending extends PermissionCreateState {
  const PermissionCreateSending();
}

/// The permission exists. The screen opens its detail from here.
final class PermissionCreated extends PermissionCreateState {
  const PermissionCreated(this.permission);

  final ScopePermission permission;
}

/// AF-25b — the API refused. The form keeps everything typed.
final class PermissionCreateRejected extends PermissionCreateState {
  const PermissionCreateRejected(this.failure);

  final Failure failure;
}

final NotifierProviderFamily<
  PermissionCreateController,
  PermissionCreateState,
  String
>
permissionCreateControllerProvider =
    NotifierProvider.family<
      PermissionCreateController,
      PermissionCreateState,
      String
    >(PermissionCreateController.new);

/// Owns one create attempt from filled in to created.
class PermissionCreateController
    extends FamilyNotifier<PermissionCreateState, String> {
  @override
  PermissionCreateState build(String scopeId) =>
      const PermissionCreateEditing();

  Future<void> create({
    required String name,
    required String description,
    required bool includeAsJwtClaim,
  }) async {
    if (state is PermissionCreateSending) {
      return;
    }

    state = const PermissionCreateSending();

    final result = await ref
        .read(scopePermissionRepositoryProvider)
        .create(
          scopeId: arg,
          name: name,
          description: description,
          includeAsJwtClaim: includeAsJwtClaim,
        );

    state = result.fold(
      onSuccess: PermissionCreated.new,
      onFailure: PermissionCreateRejected.new,
    );
  }
}
