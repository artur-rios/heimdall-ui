import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/erasure_request_repository.dart';
import '../domain/outstanding_erasure.dart';

/// What the listing is currently asking the API for.
class ErasureRequestQuery {
  const ErasureRequestQuery({this.overdueOnly = false, this.pageNumber = 1});

  final bool overdueOnly;
  final int pageNumber;

  /// Whether the listing is narrowed, which is what tells "nothing is overdue"
  /// from "nothing is outstanding" (AF-32a, AF-32b).
  bool get isFiltered => overdueOnly;

  ErasureRequestQuery copyWith({bool? overdueOnly, int? pageNumber}) =>
      ErasureRequestQuery(
        overdueOnly: overdueOnly ?? this.overdueOnly,
        pageNumber: pageNumber ?? this.pageNumber,
      );
}

/// How far the listing has got.
sealed class ErasureRequestListState {
  const ErasureRequestListState(this.query);

  final ErasureRequestQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class ErasureRequestListLoading extends ErasureRequestListState {
  const ErasureRequestListLoading(super.query);
}

/// A page arrived.
final class ErasureRequestListLoaded extends ErasureRequestListState {
  const ErasureRequestListLoaded(super.query, this.page, {this.busy = false});

  final Page<OutstandingErasure> page;
  final bool busy;
}

/// AF-32c and AF-32h — the request failed, and the query that failed is kept.
final class ErasureRequestListFailed extends ErasureRequestListState {
  const ErasureRequestListFailed(super.query, this.failure);

  final Failure failure;
}

final NotifierProvider<ErasureRequestListController, ErasureRequestListState>
erasureRequestListControllerProvider =
    NotifierProvider<ErasureRequestListController, ErasureRequestListState>(
      ErasureRequestListController.new,
    );

/// Owns the outstanding-erasure listing.
class ErasureRequestListController extends Notifier<ErasureRequestListState> {
  bool _inFlight = false;

  /// The newest query asked for while another was in flight. It is asked as
  /// soon as that one is answered, so a change made during a load is not lost.
  ErasureRequestQuery? _queued;

  @override
  ErasureRequestListState build() =>
      const ErasureRequestListLoading(ErasureRequestQuery());

  Future<void> load() => _fetch(state.query);

  /// A new filter starts at the first page.
  Future<void> setOverdueOnly(bool overdueOnly) =>
      _fetch(state.query.copyWith(overdueOnly: overdueOnly, pageNumber: 1));

  Future<void> goToPage(int pageNumber) =>
      _fetch(state.query.copyWith(pageNumber: pageNumber));

  Future<void> _fetch(ErasureRequestQuery query) async {
    if (_inFlight) {
      _queued = query;

      return;
    }

    final current = state;
    _inFlight = true;

    state = current is ErasureRequestListLoaded
        ? ErasureRequestListLoaded(query, current.page, busy: true)
        : ErasureRequestListLoading(query);

    try {
      final result = await guardUnexpected(
        () => ref
            .read(erasureRequestRepositoryProvider)
            .list(overdueOnly: query.overdueOnly, pageNumber: query.pageNumber),
      );

      state = result.fold(
        onSuccess: (page) => ErasureRequestListLoaded(query, page),
        onFailure: (failure) => ErasureRequestListFailed(query, failure),
      );
    } finally {
      _inFlight = false;
    }

    if (_queued case final queued?) {
      _queued = null;
      await _fetch(queued);

      return;
    }

    // A page past the end — the last request on the last page was carried out,
    // say — would show "nothing here" with no pager to go back with.
    if (state case ErasureRequestListLoaded(:final page)
        when page.items.isEmpty && query.pageNumber > 1) {
      await _fetch(
        query.copyWith(
          pageNumber: page.totalPages.clamp(1, query.pageNumber - 1),
        ),
      );
    }
  }
}
