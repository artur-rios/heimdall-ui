import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../domain/google_user.dart';
import '../domain/google_user_repository.dart';

/// Which Google User a detail screen is showing.
class GoogleUserRef {
  const GoogleUserRef({required this.scopeId, required this.googleUserId});

  final String scopeId;
  final String googleUserId;

  @override
  bool operator ==(Object other) =>
      other is GoogleUserRef &&
      other.scopeId == scopeId &&
      other.googleUserId == googleUserId;

  @override
  int get hashCode => Object.hash(scopeId, googleUserId);
}

/// How far the Google user detail has got.
sealed class GoogleUserDetailState {
  const GoogleUserDetailState();
}

/// The record is being read.
final class GoogleUserDetailLoading extends GoogleUserDetailState {
  const GoogleUserDetailLoading();
}

/// The record could not be read.
final class GoogleUserDetailUnavailable extends GoogleUserDetailState {
  const GoogleUserDetailUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The Google User is gone, and the screen returns to the listing.
final class GoogleUserDeleted extends GoogleUserDetailState {
  const GoogleUserDeleted();
}

/// The record is on screen.
///
/// AF-28e: there is nothing to save here. Every field comes from Google, so
/// the only thing this state carries beyond the record is the deletion.
final class GoogleUserDetailLoaded extends GoogleUserDetailState {
  const GoogleUserDetailLoaded(
    this.user, {
    this.deleting = false,
    this.deleteFailure,
  });

  final GoogleUser user;

  /// A deletion is on its way. Both controls are disabled while it is.
  final bool deleting;

  /// AF-29b — the API refused to delete, and the record stays open.
  final Failure? deleteFailure;

  GoogleUserDetailLoaded copyWith({
    GoogleUser? user,
    bool? deleting,
    Failure? deleteFailure,
    bool clearDeleteFailure = false,
  }) => GoogleUserDetailLoaded(
    user ?? this.user,
    deleting: deleting ?? this.deleting,
    deleteFailure: clearDeleteFailure
        ? null
        : (deleteFailure ?? this.deleteFailure),
  );
}

final NotifierProviderFamily<
  GoogleUserDetailController,
  GoogleUserDetailState,
  GoogleUserRef
>
googleUserDetailControllerProvider =
    NotifierProvider.family<
      GoogleUserDetailController,
      GoogleUserDetailState,
      GoogleUserRef
    >(GoogleUserDetailController.new);

/// Owns one Google user's detail. Reading it is all there is to do.
class GoogleUserDetailController extends Notifier<GoogleUserDetailState>
    with BuildEpoch<GoogleUserDetailState> {
  GoogleUserDetailController(this.arg);

  /// The family argument this controller was created for.
  final GoogleUserRef arg;

  @override
  GoogleUserDetailState build() {
    startEpoch();

    return const GoogleUserDetailLoading();
  }

  Future<void> load() async {
    // A save or delete in flight owns the state: loading over it would drop
    // its `saving`/`deleting` guard and let its answer overwrite the reread.
    final current = state;

    if (current is GoogleUserDetailLoaded && (current.deleting)) {
      return;
    }

    state = const GoogleUserDetailLoading();

    final epoch = this.epoch;
    final result = await ref
        .read(googleUserRepositoryProvider)
        .getById(scopeId: arg.scopeId, id: arg.googleUserId);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    state = result.fold(
      onSuccess: GoogleUserDetailLoaded.new,
      onFailure: GoogleUserDetailUnavailable.new,
    );
  }

  /// Logically deletes the Google User. The record is hidden, not erased.
  /// The API has no restore: only an operator can undo it, in the
  /// database, within the retention window. The confirmation says so
  /// before this is called.
  Future<void> delete() => _delete(
    (repository) =>
        repository.delete(scopeId: arg.scopeId, id: arg.googleUserId),
  );

  /// Permanently deletes the Google User.
  Future<void> deletePermanently() => _delete(
    (repository) =>
        repository.hardDelete(scopeId: arg.scopeId, id: arg.googleUserId),
  );

  Future<void> _delete(
    Future<Result<void>> Function(GoogleUserRepository repository) send,
  ) async {
    final current = state;

    if (current is! GoogleUserDetailLoaded || current.deleting) {
      return;
    }

    state = current.copyWith(deleting: true, clearDeleteFailure: true);

    final epoch = this.epoch;
    final result = await send(ref.read(googleUserRepositoryProvider));

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    switch (result) {
      case Success<void>():
        state = const GoogleUserDeleted();
      case FailureResult<void>(:final failure):
        // Somebody already deleted them, which is the outcome that was asked
        // for.
        state = failure.kind == FailureKind.notFound
            ? const GoogleUserDeleted()
            : current.copyWith(deleting: false, deleteFailure: failure);
    }
  }
}
