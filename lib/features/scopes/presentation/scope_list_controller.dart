import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
import '../domain/scope.dart';
import '../domain/scope_repository.dart';

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<ScopeRepository> scopeRepositoryProvider =
    Provider<ScopeRepository>(
      (ref) => throw UnimplementedError(
        'scopeRepositoryProvider must be overridden',
      ),
    );

/// What the listing is currently asking the API for.
///
/// Kept whole rather than as loose fields so a failed request can be repeated
/// with exactly the question that failed (FR-UX-07).
class ScopeQuery {
  const ScopeQuery({
    this.name = '',
    this.includeDeleted = false,
    this.pageNumber = 1,
  });

  final String name;
  final bool includeDeleted;
  final int pageNumber;

  /// Whether the user has narrowed the listing at all, which is what tells an
  /// empty result from an unfiltered empty collection (AF-10a).
  bool get isFiltered => name.trim().isNotEmpty || includeDeleted;

  ScopeQuery copyWith({String? name, bool? includeDeleted, int? pageNumber}) =>
      ScopeQuery(
        name: name ?? this.name,
        includeDeleted: includeDeleted ?? this.includeDeleted,
        pageNumber: pageNumber ?? this.pageNumber,
      );
}

/// How far the listing has got. The query travels with every state, so the
/// filters survive a failure and a retry.
sealed class ScopeListState implements ListState<ScopeQuery, Scope> {
  const ScopeListState(this.query);

  @override
  final ScopeQuery query;
}

/// AF-10e — the first page is on its way and the list shows a placeholder.
final class ScopeListLoading extends ScopeListState
    implements ListLoading<ScopeQuery, Scope> {
  const ScopeListLoading(super.query);
}

/// A page arrived. [busy] marks a further page or filter in flight, which keeps
/// the current rows on screen instead of flashing the placeholder again.
final class ScopeListLoaded extends ScopeListState
    implements ListLoaded<ScopeQuery, Scope> {
  const ScopeListLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<Scope> page;

  @override
  final bool busy;
}

/// AF-10b — the request failed, and the query that failed is kept.
final class ScopeListFailed extends ScopeListState
    implements ListFailed<ScopeQuery, Scope> {
  const ScopeListFailed(super.query, this.failure);

  @override
  final Failure failure;
}

final NotifierProvider<ScopeListController, ScopeListState>
scopeListControllerProvider =
    NotifierProvider<ScopeListController, ScopeListState>(
      ScopeListController.new,
    );

/// Owns the scope listing: the filters, the page, and the request in flight.
class ScopeListController
    extends PagedListController<ScopeQuery, Scope, ScopeListState> {
  /// AF-10d — a new search starts at the first page. Leaving the user on page
  /// four of a listing they just narrowed would show them an empty page that is
  /// not actually empty.
  Future<void> search(String name) =>
      request(latest.copyWith(name: name, pageNumber: 1));

  /// AF-10d — as with the search, changing what is included starts over.
  Future<void> setIncludeDeleted(bool includeDeleted) =>
      request(latest.copyWith(includeDeleted: includeDeleted, pageNumber: 1));

  /// AF-10a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => request(const ScopeQuery());

  @override
  ScopeQuery get initialQuery => const ScopeQuery();

  @override
  int pageNumberOf(ScopeQuery query) => query.pageNumber;

  @override
  ScopeQuery withPageNumber(ScopeQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<Scope>>> fetch(ScopeQuery query) => ref
      .read(scopeRepositoryProvider)
      .list(
        name: query.name,
        includeDeleted: query.includeDeleted,
        pageNumber: query.pageNumber,
      );

  @override
  ScopeListState loadingState(ScopeQuery query) => ScopeListLoading(query);

  @override
  ScopeListState loadedState(
    ScopeQuery query,
    Page<Scope> page, {
    bool busy = false,
  }) => ScopeListLoaded(query, page, busy: busy);

  @override
  ScopeListState failedState(ScopeQuery query, Failure failure) =>
      ScopeListFailed(query, failure);
}
