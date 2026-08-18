import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
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
sealed class ScopeListState {
  const ScopeListState(this.query);

  final ScopeQuery query;
}

/// AF-10e — the first page is on its way and the list shows a placeholder.
final class ScopeListLoading extends ScopeListState {
  const ScopeListLoading(super.query);
}

/// A page arrived. [busy] marks a further page or filter in flight, which keeps
/// the current rows on screen instead of flashing the placeholder again.
final class ScopeListLoaded extends ScopeListState {
  const ScopeListLoaded(super.query, this.page, {this.busy = false});

  final Page<Scope> page;
  final bool busy;
}

/// AF-10b — the request failed, and the query that failed is kept.
final class ScopeListFailed extends ScopeListState {
  const ScopeListFailed(super.query, this.failure);

  final Failure failure;
}

final NotifierProvider<ScopeListController, ScopeListState>
scopeListControllerProvider =
    NotifierProvider<ScopeListController, ScopeListState>(
      ScopeListController.new,
    );

/// Owns the scope listing: the filters, the page, and the request in flight.
class ScopeListController extends Notifier<ScopeListState> {
  /// Whether a request is already on its way.
  ///
  /// A field rather than a read of [state], because the first load and a later
  /// page are in different states while being equally in flight, and a second
  /// request either way would race the first to set the result.
  bool _inFlight = false;

  @override
  ScopeListState build() => const ScopeListLoading(ScopeQuery());

  /// Reads the page the current query names.
  Future<void> load() => _fetch(state.query);

  /// AF-10d — a new search starts at the first page. Leaving the user on page
  /// four of a listing they just narrowed would show them an empty page that is
  /// not actually empty.
  Future<void> search(String name) =>
      _fetch(state.query.copyWith(name: name, pageNumber: 1));

  /// AF-10d — as with the search, changing what is included starts over.
  Future<void> setIncludeDeleted(bool includeDeleted) => _fetch(
    state.query.copyWith(includeDeleted: includeDeleted, pageNumber: 1),
  );

  Future<void> goToPage(int pageNumber) =>
      _fetch(state.query.copyWith(pageNumber: pageNumber));

  /// AF-10a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => _fetch(const ScopeQuery());

  Future<void> _fetch(ScopeQuery query) async {
    if (_inFlight) {
      return;
    }

    final current = state;
    _inFlight = true;

    // The rows already on screen stay while the next page loads; only a
    // listing with nothing to show falls back to the placeholder.
    state = current is ScopeListLoaded
        ? ScopeListLoaded(query, current.page, busy: true)
        : ScopeListLoading(query);

    try {
      final result = await ref
          .read(scopeRepositoryProvider)
          .list(
            name: query.name,
            includeDeleted: query.includeDeleted,
            pageNumber: query.pageNumber,
          );

      state = result.fold(
        onSuccess: (page) => ScopeListLoaded(query, page),
        onFailure: (failure) => ScopeListFailed(query, failure),
      );
    } finally {
      _inFlight = false;
    }
  }
}
