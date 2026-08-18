import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/scope_permission.dart';
import '../domain/scope_permission_repository.dart';

/// Which permission a detail screen is showing.
///
/// A permission is identified by its scope as well as itself, so the family is
/// keyed by both rather than by the identifier alone.
class PermissionRef {
  const PermissionRef({required this.scopeId, required this.permissionId});

  final String scopeId;
  final String permissionId;

  @override
  bool operator ==(Object other) =>
      other is PermissionRef &&
      other.scopeId == scopeId &&
      other.permissionId == permissionId;

  @override
  int get hashCode => Object.hash(scopeId, permissionId);
}

/// How far the permission detail has got.
sealed class PermissionDetailState {
  const PermissionDetailState();
}

/// The record is being read.
final class PermissionDetailLoading extends PermissionDetailState {
  const PermissionDetailLoading();
}

/// AF-26a and AF-26b — the record could not be read.
final class PermissionDetailUnavailable extends PermissionDetailState {
  const PermissionDetailUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The permission is gone, and the screen returns to the listing.
final class PermissionDeleted extends PermissionDetailState {
  const PermissionDeleted();
}

/// The record is on screen.
final class PermissionDetailLoaded extends PermissionDetailState {
  const PermissionDetailLoaded(
    this.permission, {
    this.saving = false,
    this.saveFailure,
    this.saved = false,
    this.claimChanged = false,
    this.deleting = false,
    this.deleteFailure,
  });

  final ScopePermission permission;
  final bool saving;
  final Failure? saveFailure;
  final bool saved;

  /// A deletion is on its way. Both controls are disabled while it is.
  final bool deleting;

  /// AF-27b — the API refused to delete, and the permission stays open.
  final Failure? deleteFailure;

  /// AF-26e — the claim flag differs from what it was before the save, which
  /// is what the confirmation has to explain.
  final bool claimChanged;

  /// AF-26d — a logically deleted permission is shown, but nothing about it
  /// may be changed from here.
  bool get isReadOnly => permission.isDeleted;

  PermissionDetailLoaded copyWith({
    ScopePermission? permission,
    bool? saving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? saved,
    bool? claimChanged,
    bool? deleting,
    Failure? deleteFailure,
    bool clearDeleteFailure = false,
  }) => PermissionDetailLoaded(
    permission ?? this.permission,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
    claimChanged: claimChanged ?? this.claimChanged,
    deleting: deleting ?? this.deleting,
    deleteFailure: clearDeleteFailure
        ? null
        : (deleteFailure ?? this.deleteFailure),
  );
}

final NotifierProviderFamily<
  PermissionDetailController,
  PermissionDetailState,
  PermissionRef
>
permissionDetailControllerProvider =
    NotifierProvider.family<
      PermissionDetailController,
      PermissionDetailState,
      PermissionRef
    >(PermissionDetailController.new);

/// Owns one permission's detail: reading it, and saving edits to it.
class PermissionDetailController
    extends FamilyNotifier<PermissionDetailState, PermissionRef> {
  @override
  PermissionDetailState build(PermissionRef ref) =>
      const PermissionDetailLoading();

  Future<void> load() async {
    state = const PermissionDetailLoading();

    final result = await ref
        .read(scopePermissionRepositoryProvider)
        .getById(scopeId: arg.scopeId, id: arg.permissionId);

    state = result.fold(
      onSuccess: PermissionDetailLoaded.new,
      onFailure: PermissionDetailUnavailable.new,
    );
  }

  Future<void> save({
    required String name,
    required String description,
    required bool includeAsJwtClaim,
  }) async {
    final current = state;

    if (current is! PermissionDetailLoaded ||
        current.saving ||
        current.isReadOnly) {
      return;
    }

    final previous = current.permission;

    if (name == previous.name &&
        description == previous.description &&
        includeAsJwtClaim == previous.includeAsJwtClaim) {
      return;
    }

    state = current.copyWith(
      saving: true,
      clearSaveFailure: true,
      saved: false,
    );

    final result = await ref
        .read(scopePermissionRepositoryProvider)
        .update(
          scopeId: arg.scopeId,
          id: arg.permissionId,
          name: name,
          description: description,
          includeAsJwtClaim: includeAsJwtClaim,
        );

    state = result.fold(
      onSuccess: (permission) => PermissionDetailLoaded(
        permission,
        saved: true,
        // AF-26e: the tokens issued from now on carry the change, and the
        // ones already out there do not — which is worth saying only when the
        // flag actually moved.
        claimChanged:
            permission.includeAsJwtClaim != previous.includeAsJwtClaim,
      ),
      // AF-26c: the refusal is kept as it came back, and the record on screen
      // is still the one the API last confirmed.
      onFailure: (failure) =>
          current.copyWith(saving: false, saveFailure: failure),
    );
  }

  /// Drops the "saved" acknowledgement so a later edit starts clean.
  void acknowledgeSave() {
    if (state case final PermissionDetailLoaded loaded) {
      state = loaded.copyWith(saved: false, claimChanged: false);
    }
  }

  /// Logically deletes the permission. The record is kept and the API can
  /// restore it, which is what the confirmation says before this is called.
  Future<void> delete() => _delete(
    (repository) =>
        repository.delete(scopeId: arg.scopeId, id: arg.permissionId),
  );

  /// Permanently deletes the permission.
  Future<void> deletePermanently() => _delete(
    (repository) =>
        repository.hardDelete(scopeId: arg.scopeId, id: arg.permissionId),
  );

  Future<void> _delete(
    Future<Result<void>> Function(ScopePermissionRepository repository) send,
  ) async {
    final current = state;

    if (current is! PermissionDetailLoaded || current.deleting) {
      return;
    }

    state = current.copyWith(deleting: true, clearDeleteFailure: true);

    final result = await send(ref.read(scopePermissionRepositoryProvider));

    switch (result) {
      case Success<void>():
        state = const PermissionDeleted();
      case FailureResult<void>(:final failure):
        // Somebody already deleted it, which is the outcome that was asked
        // for.
        state = failure.kind == FailureKind.notFound
            ? const PermissionDeleted()
            : current.copyWith(deleting: false, deleteFailure: failure);
    }
  }
}
