import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/envelope.dart';
import '../../core/result/result.dart';
import '../../core/state/build_epoch.dart';
import 'list_state.dart';

/// The one paging engine behind every list screen: it owns the request in
/// flight, the query queued behind it, and what happens when an answer lands.
///
/// [Q] is the feature's query, [T] the row it lists and [S] its sealed state,
/// whose classes implement [ListLoading], [ListLoaded] and [ListFailed]. A
/// feature supplies the hooks — how to read and set the page of a query, how to
/// build each state, and [fetch], the repository call — and its own filter
/// methods, each of which builds on [latest] and hands the result to
/// [request]:
///
/// ```dart
/// Future<void> search(String name) =>
///     request(latest.copyWith(name: name, pageNumber: 1));
/// ```
///
/// In return every listing behaves the same way:
///
/// - one request at a time. A query asked for while another is in flight
///   waits, and only the newest one waiting is asked once that one is
///   answered;
/// - a change made while a request is in flight builds on the query already
///   waiting, so a search typed and then a switch flipped during one load both
///   reach the request that follows it (#157);
/// - the rows on screen stay, marked busy, while the next page or filter loads;
/// - an answer the client cannot read ends in the failed state, never an
///   endless placeholder (FR-UX-07);
/// - a page past the end steps back to the last page that still exists;
/// - an answer to a request of an earlier build — the session ended since it
///   was asked — is dropped ([BuildEpoch]).
abstract class PagedListController<
  Q extends Object,
  T,
  S extends ListState<Q, T>
>
    extends Notifier<S>
    with BuildEpoch<S> {
  /// Whether a request is already on its way.
  ///
  /// A field rather than a read of [state], because the first load and a later
  /// page are in different states while being equally in flight, and a second
  /// request either way would race the first to set the result.
  bool _inFlight = false;

  /// The newest query asked for while another was in flight. It is asked as
  /// soon as that one is answered, so a change made during a load is not lost.
  Q? _queued;

  /// What the next change builds on: the query waiting its turn when there is
  /// one, else the one on screen. Building on [state]'s query instead would
  /// drop a change made earlier during the same load.
  @protected
  Q get latest => _queued ?? state.query;

  /// The query a fresh listing starts from: no filters, the first page.
  @protected
  Q get initialQuery;

  @protected
  int pageNumberOf(Q query);

  /// [query] asking for [pageNumber] instead, its filters unchanged.
  @protected
  Q withPageNumber(Q query, int pageNumber);

  /// Reads the page [query] names. Run inside [guardUnexpected], so it may
  /// throw what a malformed answer throws.
  @protected
  Future<Result<Page<T>>> fetch(Q query);

  @protected
  S loadingState(Q query);

  /// [busy] is set while [page] stays on screen for a [query] in flight.
  @protected
  S loadedState(Q query, Page<T> page, {bool busy = false});

  @protected
  S failedState(Q query, Failure failure);

  @override
  S build() {
    startEpoch();
    // A request of an earlier build may still be in flight; it is not this
    // build's, which has asked for nothing yet.
    _inFlight = false;
    _queued = null;

    return loadingState(initialQuery);
  }

  /// Reads the page the current query names, or the query waiting its turn.
  Future<void> load() => request(latest);

  Future<void> goToPage(int pageNumber) =>
      request(withPageNumber(latest, pageNumber));

  /// Asks for [query], or queues it behind the request in flight.
  ///
  /// Completes once [query] — or whatever replaced it in the queue — has been
  /// answered and shown.
  @protected
  Future<void> request(Q query) async {
    if (_inFlight) {
      _queued = query;

      return;
    }

    final epoch = this.epoch;
    final shown = state;
    _inFlight = true;

    // The rows already on screen stay while the next page loads; only a
    // listing with nothing to show falls back to the placeholder.
    state = shown is ListLoaded<Q, T>
        ? loadedState(query, shown.page, busy: true)
        : loadingState(query);

    try {
      final result = await guardUnexpected(() => fetch(query));

      // Reset since it was asked: the answer is an earlier build's.
      if (!isCurrent(epoch)) {
        return;
      }

      state = result.fold(
        onSuccess: (page) => loadedState(query, page),
        onFailure: (failure) => failedState(query, failure),
      );
    } finally {
      if (isCurrent(epoch)) {
        _inFlight = false;
      }
    }

    if (_queued case final queued?) {
      _queued = null;
      await request(queued);

      return;
    }

    // A page past the end — the last row of the last page was deleted, say,
    // or a narrowed filter left fewer pages — would show "nothing here" with
    // no pager to go back with. The last page that still exists is asked for
    // instead.
    final pageNumber = pageNumberOf(query);

    if (state case ListLoaded<Q, T>(:final page)
        when page.items.isEmpty && pageNumber > 1) {
      await request(
        withPageNumber(query, page.totalPages.clamp(1, pageNumber - 1)),
      );
    }
  }
}
