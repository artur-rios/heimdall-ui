import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/scope.dart';
import '../domain/scope_repository.dart';
import 'scope_list_controller.dart';

/// How far the scope detail has got.
sealed class ScopeDetailState {
  const ScopeDetailState();
}

/// The record is being read.
final class ScopeDetailLoading extends ScopeDetailState {
  const ScopeDetailLoading();
}

/// AF-12a and AF-12b — the record could not be read.
///
/// The [failure]'s kind is what separates "no such scope" from "not yours",
/// and the screen shows a different panel for each.
final class ScopeDetailUnavailable extends ScopeDetailState {
  const ScopeDetailUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The scope is gone, and the screen returns to the listing.
///
/// AF-13d lands here too: a `404` means somebody already deleted it, which is
/// the outcome that was asked for rather than a failure.
final class ScopeDeleted extends ScopeDetailState {
  const ScopeDeleted();
}

/// The record is on screen.
final class ScopeDetailLoaded extends ScopeDetailState {
  const ScopeDetailLoaded(
    this.scope, {
    this.saving = false,
    this.saveFailure,
    this.saved = false,
    this.deleting = false,
    this.deleteFailure,
    this.togglingGoogleSignIn = false,
    this.googleSignInFailure,
  });

  final Scope scope;
  final bool saving;
  final Failure? saveFailure;
  final bool saved;

  /// A deletion is on its way. Both controls are disabled while it is, so a
  /// second tap cannot send a second request.
  final bool deleting;

  /// AF-13b — the API refused to delete, and the scope stays open.
  final Failure? deleteFailure;

  /// AF-15c — the Google Sign-In request is outstanding, so the control is
  /// disabled and cannot be toggled twice.
  final bool togglingGoogleSignIn;

  /// AF-15a — the API refused the toggle, and the control went back.
  final Failure? googleSignInFailure;

  /// AF-12d — a logically deleted scope is shown, but nothing about it may be
  /// changed from here.
  bool get isReadOnly => scope.isDeleted;

  ScopeDetailLoaded copyWith({
    Scope? scope,
    bool? saving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? saved,
    bool? deleting,
    Failure? deleteFailure,
    bool clearDeleteFailure = false,
    bool? togglingGoogleSignIn,
    Failure? googleSignInFailure,
    bool clearGoogleSignInFailure = false,
  }) => ScopeDetailLoaded(
    scope ?? this.scope,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
    deleting: deleting ?? this.deleting,
    deleteFailure: clearDeleteFailure
        ? null
        : (deleteFailure ?? this.deleteFailure),
    togglingGoogleSignIn: togglingGoogleSignIn ?? this.togglingGoogleSignIn,
    googleSignInFailure: clearGoogleSignInFailure
        ? null
        : (googleSignInFailure ?? this.googleSignInFailure),
  );
}

/// Family-keyed on the scope's identifier, so two detail screens opened from
/// two tabs do not share one state.
final NotifierProviderFamily<ScopeDetailController, ScopeDetailState, String>
scopeDetailControllerProvider =
    NotifierProvider.family<ScopeDetailController, ScopeDetailState, String>(
      ScopeDetailController.new,
    );

/// Owns one scope's detail: reading it, and saving edits to it.
class ScopeDetailController extends FamilyNotifier<ScopeDetailState, String> {
  @override
  ScopeDetailState build(String scopeId) => const ScopeDetailLoading();

  /// Reads the scope.
  ///
  /// Deleted scopes are included: AF-12d shows one read-only, and it cannot do
  /// that if the API is asked to pretend it is gone.
  Future<void> load() async {
    state = const ScopeDetailLoading();

    final result = await ref.read(scopeRepositoryProvider).getById(arg);

    state = result.fold(
      onSuccess: ScopeDetailLoaded.new,
      onFailure: ScopeDetailUnavailable.new,
    );
  }

  /// Saves [name] and [description].
  ///
  /// AF-12e is enforced by the screen, which keeps the control disabled until
  /// something differs; the same comparison is repeated here so a submission
  /// from the keyboard obeys it too.
  Future<void> save({required String name, required String description}) async {
    final current = state;

    if (current is! ScopeDetailLoaded || current.saving || current.isReadOnly) {
      return;
    }

    if (name == current.scope.name &&
        description == current.scope.description) {
      return;
    }

    state = current.copyWith(
      saving: true,
      clearSaveFailure: true,
      saved: false,
    );

    final result = await ref
        .read(scopeRepositoryProvider)
        .update(id: arg, name: name, description: description);

    state = result.fold(
      onSuccess: (scope) => ScopeDetailLoaded(scope, saved: true),
      // AF-12c: the refusal is kept as it came back, and the record on screen
      // is still the one the API last confirmed.
      onFailure: (failure) =>
          current.copyWith(saving: false, saveFailure: failure),
    );
  }

  /// Drops the "saved" acknowledgement so a later edit starts clean.
  void acknowledgeSave() {
    if (state case final ScopeDetailLoaded loaded) {
      state = loaded.copyWith(saved: false);
    }
  }

  /// UI-15 — turns Google Sign-In on or off.
  ///
  /// The control settles on what the API confirmed, not on what it was moved
  /// to: a refusal leaves the scope exactly as the API still holds it
  /// (AF-15a), and the request in flight disables the control (AF-15c).
  Future<void> setGoogleSignIn(bool enabled) async {
    final current = state;

    if (current is! ScopeDetailLoaded ||
        current.togglingGoogleSignIn ||
        current.isReadOnly) {
      return;
    }

    state = current.copyWith(
      togglingGoogleSignIn: true,
      clearGoogleSignInFailure: true,
    );

    final result = await ref
        .read(scopeRepositoryProvider)
        .setGoogleSignIn(id: arg, enabled: enabled);

    state = result.fold(
      onSuccess: (scope) =>
          current.copyWith(scope: scope, togglingGoogleSignIn: false),
      onFailure: (failure) => current.copyWith(
        togglingGoogleSignIn: false,
        googleSignInFailure: failure,
      ),
    );
  }

  /// Logically deletes the scope. The record is kept and the API can restore
  /// it, which is what the confirmation says before this is called.
  Future<void> delete() => _delete((repository) => repository.delete(arg));

  /// Permanently deletes the scope and everything it holds.
  Future<void> deletePermanently() =>
      _delete((repository) => repository.hardDelete(arg));

  Future<void> _delete(
    Future<Result<void>> Function(ScopeRepository repository) send,
  ) async {
    final current = state;

    if (current is! ScopeDetailLoaded || current.deleting) {
      return;
    }

    state = current.copyWith(deleting: true, clearDeleteFailure: true);

    final result = await send(ref.read(scopeRepositoryProvider));

    switch (result) {
      case Success<void>():
        state = const ScopeDeleted();
      case FailureResult<void>(:final failure):
        // AF-13d: the scope is already gone, which is the outcome that was
        // asked for. Reporting it as a failure would ask the user to delete
        // something that no longer exists.
        state = failure.kind == FailureKind.notFound
            ? const ScopeDeleted()
            : current.copyWith(deleting: false, deleteFailure: failure);
    }
  }
}
