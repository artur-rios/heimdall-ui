import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';

/// How far the Scope Admin listing behind an owner picker has got.
sealed class ScopeAdminsState {
  const ScopeAdminsState();
}

/// The candidates are being read.
final class ScopeAdminsLoading extends ScopeAdminsState {
  const ScopeAdminsLoading();
}

/// The candidates could not be read, so the picker offers a typed identifier
/// instead of nothing — naming an owner was possible before this listing
/// existed and stays possible without it.
final class ScopeAdminsUnavailable extends ScopeAdminsState {
  const ScopeAdminsUnavailable(this.failure);

  final Failure failure;
}

/// The candidates are on screen.
final class ScopeAdminsLoaded extends ScopeAdminsState {
  const ScopeAdminsLoaded({
    required this.candidates,
    this.query = '',
    this.searching = false,
  });

  final List<PersonSummary> candidates;

  /// What the search field was asked for, kept so a reread repeats it.
  final String query;

  /// A narrowed listing is on its way. The list stays on screen while it is.
  final bool searching;
}

final NotifierProviderFamily<
  ScopeAdminPickerController,
  ScopeAdminsState,
  String
>
scopeAdminPickerControllerProvider =
    NotifierProvider.family<
      ScopeAdminPickerController,
      ScopeAdminsState,
      String
    >(ScopeAdminPickerController.new);

/// Owns the Scope Admin candidates one picker offers.
///
/// The family argument is the scope whose current owners are left out, or the
/// empty string when there is none to leave out — UI-11 is creating the scope,
/// so nobody owns it yet.
class ScopeAdminPickerController
    extends FamilyNotifier<ScopeAdminsState, String> {
  @override
  ScopeAdminsState build(String excludeOwnersOfScopeId) =>
      const ScopeAdminsLoading();

  /// Reads the candidates, optionally narrowed by what was typed.
  ///
  /// A query containing an `@` is an address and anything else is a name: one
  /// field is what a picker wants, and two would ask the user to classify what
  /// they typed before typing it.
  Future<void> search([String query = '']) async {
    final trimmed = query.trim();
    final current = state;

    state = current is ScopeAdminsLoaded
        ? ScopeAdminsLoaded(
            candidates: current.candidates,
            query: trimmed,
            searching: true,
          )
        : const ScopeAdminsLoading();

    final result = await ref
        .read(personRepositoryProvider)
        .listScopeAdmins(
          name: trimmed.contains('@') ? null : trimmed,
          email: trimmed.contains('@') ? trimmed : null,
          excludeOwnersOfScopeId: arg.isEmpty ? null : arg,
          pageSize: 50,
        );

    state = switch (result) {
      Success<Page<PersonSummary>>(:final value) => ScopeAdminsLoaded(
        candidates: value.items,
        query: trimmed,
      ),
      FailureResult<Page<PersonSummary>>(:final failure) =>
        ScopeAdminsUnavailable(failure),
    };
  }
}
