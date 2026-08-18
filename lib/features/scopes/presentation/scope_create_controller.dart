import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/scope.dart';
import 'scope_list_controller.dart';

/// How far a create attempt has got.
sealed class ScopeCreateState {
  const ScopeCreateState();
}

/// The form is being filled in.
final class ScopeCreateEditing extends ScopeCreateState {
  const ScopeCreateEditing();
}

/// A request is in flight. The form refuses a second submission in this state,
/// so a double tap cannot create two scopes.
final class ScopeCreateSending extends ScopeCreateState {
  const ScopeCreateSending();
}

/// The scope exists. The screen opens its detail from here.
final class ScopeCreated extends ScopeCreateState {
  const ScopeCreated(this.scope);

  final Scope scope;
}

/// AF-11b, AF-11c, AF-11e — the API refused, or nothing reached it. The form
/// keeps everything the user typed either way.
final class ScopeCreateRejected extends ScopeCreateState {
  const ScopeCreateRejected(this.failure);

  final Failure failure;
}

final NotifierProvider<ScopeCreateController, ScopeCreateState>
scopeCreateControllerProvider =
    NotifierProvider<ScopeCreateController, ScopeCreateState>(
      ScopeCreateController.new,
    );

/// Owns one create attempt from filled in to created.
class ScopeCreateController extends Notifier<ScopeCreateState> {
  @override
  ScopeCreateState build() => const ScopeCreateEditing();

  /// Creates the scope.
  ///
  /// The owner list is the API's to judge: whether each identifier names a
  /// usable Scope Admin is a question only it can answer (AF-11c).
  Future<void> create({
    required String name,
    required String description,
    required List<String> ownerIds,
  }) async {
    if (state is ScopeCreateSending) {
      return;
    }

    state = const ScopeCreateSending();

    final result = await ref
        .read(scopeRepositoryProvider)
        .create(name: name, description: description, ownerIds: ownerIds);

    state = result.fold(
      onSuccess: ScopeCreated.new,
      onFailure: ScopeCreateRejected.new,
    );
  }

  /// AF-11e — returns a refused attempt to the form so the same submission can
  /// be made again against what is already typed.
  void backToEditing() {
    if (state is ScopeCreateRejected) {
      state = const ScopeCreateEditing();
    }
  }
}
