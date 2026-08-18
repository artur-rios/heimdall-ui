import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/scope.dart';
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

/// The record is on screen.
final class ScopeDetailLoaded extends ScopeDetailState {
  const ScopeDetailLoaded(
    this.scope, {
    this.saving = false,
    this.saveFailure,
    this.saved = false,
  });

  final Scope scope;
  final bool saving;
  final Failure? saveFailure;
  final bool saved;

  /// AF-12d — a logically deleted scope is shown, but nothing about it may be
  /// changed from here.
  bool get isReadOnly => scope.isDeleted;

  ScopeDetailLoaded copyWith({
    Scope? scope,
    bool? saving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? saved,
  }) => ScopeDetailLoaded(
    scope ?? this.scope,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
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
}
