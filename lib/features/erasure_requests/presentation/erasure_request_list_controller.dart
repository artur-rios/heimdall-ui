import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
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
sealed class ErasureRequestListState
    implements ListState<ErasureRequestQuery, OutstandingErasure> {
  const ErasureRequestListState(this.query);

  @override
  final ErasureRequestQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class ErasureRequestListLoading extends ErasureRequestListState
    implements ListLoading<ErasureRequestQuery, OutstandingErasure> {
  const ErasureRequestListLoading(super.query);
}

/// A page arrived.
final class ErasureRequestListLoaded extends ErasureRequestListState
    implements ListLoaded<ErasureRequestQuery, OutstandingErasure> {
  const ErasureRequestListLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<OutstandingErasure> page;

  @override
  final bool busy;
}

/// AF-32c and AF-32h — the request failed, and the query that failed is kept.
final class ErasureRequestListFailed extends ErasureRequestListState
    implements ListFailed<ErasureRequestQuery, OutstandingErasure> {
  const ErasureRequestListFailed(super.query, this.failure);

  @override
  final Failure failure;
}

final NotifierProvider<ErasureRequestListController, ErasureRequestListState>
erasureRequestListControllerProvider =
    NotifierProvider<ErasureRequestListController, ErasureRequestListState>(
      ErasureRequestListController.new,
    );

/// Owns the outstanding-erasure listing.
class ErasureRequestListController
    extends
        PagedListController<
          ErasureRequestQuery,
          OutstandingErasure,
          ErasureRequestListState
        > {
  /// A new filter starts at the first page.
  Future<void> setOverdueOnly(bool overdueOnly) =>
      request(latest.copyWith(overdueOnly: overdueOnly, pageNumber: 1));

  @override
  ErasureRequestQuery get initialQuery => const ErasureRequestQuery();

  @override
  int pageNumberOf(ErasureRequestQuery query) => query.pageNumber;

  @override
  ErasureRequestQuery withPageNumber(
    ErasureRequestQuery query,
    int pageNumber,
  ) => query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<OutstandingErasure>>> fetch(ErasureRequestQuery query) =>
      ref
          .read(erasureRequestRepositoryProvider)
          .list(overdueOnly: query.overdueOnly, pageNumber: query.pageNumber);

  @override
  ErasureRequestListState loadingState(ErasureRequestQuery query) =>
      ErasureRequestListLoading(query);

  @override
  ErasureRequestListState loadedState(
    ErasureRequestQuery query,
    Page<OutstandingErasure> page, {
    bool busy = false,
  }) => ErasureRequestListLoaded(query, page, busy: busy);

  @override
  ErasureRequestListState failedState(
    ErasureRequestQuery query,
    Failure failure,
  ) => ErasureRequestListFailed(query, failure);
}
