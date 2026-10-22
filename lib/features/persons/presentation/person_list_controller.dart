import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
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
sealed class PersonListState implements ListState<PersonQuery, Person> {
  const PersonListState(this.query);

  @override
  final PersonQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class PersonListLoading extends PersonListState
    implements ListLoading<PersonQuery, Person> {
  const PersonListLoading(super.query);
}

/// A page arrived. [busy] marks a further page or filter in flight, which keeps
/// the current rows on screen instead of flashing the placeholder again.
final class PersonListLoaded extends PersonListState
    implements ListLoaded<PersonQuery, Person> {
  const PersonListLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<Person> page;

  @override
  final bool busy;
}

/// AF-16b and AF-16c — the request failed, and the query that failed is kept.
final class PersonListFailed extends PersonListState
    implements ListFailed<PersonQuery, Person> {
  const PersonListFailed(super.query, this.failure);

  @override
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
class PersonListController
    extends PagedListController<PersonQuery, Person, PersonListState> {
  PersonListController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  /// AF-16d — a new search starts at the first page.
  Future<void> search({String? name, String? email}) =>
      request(latest.copyWith(name: name, email: email, pageNumber: 1));

  /// AF-16d — as does changing what is included.
  Future<void> setIncludeDeleted(bool includeDeleted) =>
      request(latest.copyWith(includeDeleted: includeDeleted, pageNumber: 1));

  /// AF-16a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => request(const PersonQuery());

  @override
  PersonQuery get initialQuery => const PersonQuery();

  @override
  int pageNumberOf(PersonQuery query) => query.pageNumber;

  @override
  PersonQuery withPageNumber(PersonQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<Person>>> fetch(PersonQuery query) => ref
      .read(personRepositoryProvider)
      .listScopePersons(
        scopeId: arg,
        name: query.name,
        email: query.email,
        includeDeleted: query.includeDeleted,
        pageNumber: query.pageNumber,
      );

  @override
  PersonListState loadingState(PersonQuery query) => PersonListLoading(query);

  @override
  PersonListState loadedState(
    PersonQuery query,
    Page<Person> page, {
    bool busy = false,
  }) => PersonListLoaded(query, page, busy: busy);

  @override
  PersonListState failedState(PersonQuery query, Failure failure) =>
      PersonListFailed(query, failure);
}
