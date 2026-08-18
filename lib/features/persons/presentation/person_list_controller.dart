import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';

/// What the listing is currently asking the API for.
///
/// Kept whole rather than as loose fields so a failed request can be repeated
/// with exactly the question that failed (FR-UX-07).
class PersonQuery {
  const PersonQuery({
    this.name = '',
    this.email = '',
    this.includeDeleted = false,
    this.pageNumber = 1,
  });

  final String name;
  final String email;
  final bool includeDeleted;
  final int pageNumber;

  /// Whether the user has narrowed the listing at all, which is what tells an
  /// empty result from an unfiltered empty collection (AF-16a).
  bool get isFiltered =>
      name.trim().isNotEmpty || email.trim().isNotEmpty || includeDeleted;

  PersonQuery copyWith({
    String? name,
    String? email,
    bool? includeDeleted,
    int? pageNumber,
  }) => PersonQuery(
    name: name ?? this.name,
    email: email ?? this.email,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    pageNumber: pageNumber ?? this.pageNumber,
  );
}

/// How far the listing has got. The query travels with every state, so the
/// filters survive a failure and a retry.
sealed class PersonListState {
  const PersonListState(this.query);

  final PersonQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class PersonListLoading extends PersonListState {
  const PersonListLoading(super.query);
}

/// A page arrived. [busy] marks a further page or filter in flight, which keeps
/// the current rows on screen instead of flashing the placeholder again.
final class PersonListLoaded extends PersonListState {
  const PersonListLoaded(super.query, this.page, {this.busy = false});

  final Page<Person> page;
  final bool busy;
}

/// AF-16b and AF-16c — the request failed, and the query that failed is kept.
final class PersonListFailed extends PersonListState {
  const PersonListFailed(super.query, this.failure);

  final Failure failure;

  /// AF-16c — a Scope Admin opening a scope they do not own.
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

final NotifierProviderFamily<PersonListController, PersonListState, String>
personListControllerProvider =
    NotifierProvider.family<PersonListController, PersonListState, String>(
      PersonListController.new,
    );

/// Owns one scope's person listing: the filters, the page, and the request in
/// flight.
class PersonListController extends FamilyNotifier<PersonListState, String> {
  /// Whether a request is already on its way.
  ///
  /// A field rather than a read of [state], because the first load and a later
  /// page are in different states while being equally in flight.
  bool _inFlight = false;

  @override
  PersonListState build(String scopeId) =>
      const PersonListLoading(PersonQuery());

  Future<void> load() => _fetch(state.query);

  /// AF-16d — a new search starts at the first page.
  Future<void> search({String? name, String? email}) =>
      _fetch(state.query.copyWith(name: name, email: email, pageNumber: 1));

  /// AF-16d — as does changing what is included.
  Future<void> setIncludeDeleted(bool includeDeleted) => _fetch(
    state.query.copyWith(includeDeleted: includeDeleted, pageNumber: 1),
  );

  Future<void> goToPage(int pageNumber) =>
      _fetch(state.query.copyWith(pageNumber: pageNumber));

  /// AF-16a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => _fetch(const PersonQuery());

  Future<void> _fetch(PersonQuery query) async {
    if (_inFlight) {
      return;
    }

    final current = state;
    _inFlight = true;

    state = current is PersonListLoaded
        ? PersonListLoaded(query, current.page, busy: true)
        : PersonListLoading(query);

    try {
      final result = await ref
          .read(personRepositoryProvider)
          .listScopePersons(
            scopeId: arg,
            name: query.name,
            email: query.email,
            includeDeleted: query.includeDeleted,
            pageNumber: query.pageNumber,
          );

      state = result.fold(
        onSuccess: (page) => PersonListLoaded(query, page),
        onFailure: (failure) => PersonListFailed(query, failure),
      );
    } finally {
      _inFlight = false;
    }
  }
}
