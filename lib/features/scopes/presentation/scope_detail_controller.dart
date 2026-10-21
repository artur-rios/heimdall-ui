import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
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
  }) => ScopeDetailLoaded(
    scope ?? this.scope,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
    deleting: deleting ?? this.deleting,
    deleteFailure: clearDeleteFailure
        ? null
        : (deleteFailure ?? this.deleteFailure),
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
class ScopeDetailController extends Notifier<ScopeDetailState>
    with BuildEpoch<ScopeDetailState> {
  ScopeDetailController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  @override
  ScopeDetailState build() {
    startEpoch();

    return const ScopeDetailLoading();
  }

  /// Reads the scope.
  ///
  /// Deleted scopes are included: AF-12d shows one read-only, and it cannot do
  /// that if the API is asked to pretend it is gone.
  Future<void> load() async {
    // A save or delete in flight owns the state: loading over it would drop
    // its `saving`/`deleting` guard and let its answer overwrite the reread.
    final current = state;

    if (current is ScopeDetailLoaded && (current.saving || current.deleting)) {
      return;
    }

    state = const ScopeDetailLoading();

    final epoch = this.epoch;
    final result = await ref.read(scopeRepositoryProvider).getById(arg);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

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

    // One request at a time: each settles on the state it started from, so
    // a second one in flight would be overwritten by whichever answers last.
    if (current is! ScopeDetailLoaded ||
        current.saving ||
        current.deleting ||
        current.isReadOnly) {
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

    // The API replaces the privacy settings on every update, so the ones the
    // scope already holds travel with the edit to keep them.
    final epoch = this.epoch;
    final result = await ref
        .read(scopeRepositoryProvider)
        .update(
          id: arg,
          name: name,
          description: description,
          defaultLegalBasis: current.scope.defaultLegalBasis,
          privacyNoticeUri: current.scope.privacyNoticeUri,
        );

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    state = result.fold(
      onSuccess: (scope) => ScopeDetailLoaded(scope, saved: true),
      // AF-12c: the refusal is kept as it came back, and the record on screen
      // is still the one the API last confirmed.
      onFailure: (failure) =>
          current.copyWith(saving: false, saveFailure: failure),
    );
  }

  /// Drops the "saved" acknowledgement and any refused save, so a later edit
  /// starts clean.
  void acknowledgeSave() {
    if (state case final ScopeDetailLoaded loaded) {
      state = loaded.copyWith(saved: false, clearSaveFailure: true);
    }
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

    if (current is! ScopeDetailLoaded || current.deleting || current.saving) {
      return;
    }

    state = current.copyWith(deleting: true, clearDeleteFailure: true);

    final epoch = this.epoch;
    final result = await send(ref.read(scopeRepositoryProvider));

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

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
