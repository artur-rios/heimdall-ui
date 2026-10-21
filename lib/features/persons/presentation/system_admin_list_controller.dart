import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/person.dart';

/// What the System Admins listing is asking the API for (UI-38).
class SystemAdminQuery {
  const SystemAdminQuery({
    this.name = '',
    this.email = '',
    this.pageNumber = 1,
  });

  final String name;
  final String email;
  final int pageNumber;

  /// Whether the admin has narrowed the listing, which tells "no matches"
  /// from "nobody" (AF-38a/b).
  bool get isFiltered => name.trim().isNotEmpty || email.trim().isNotEmpty;

  SystemAdminQuery copyWith({String? name, String? email, int? pageNumber}) =>
      SystemAdminQuery(
        name: name ?? this.name,
        email: email ?? this.email,
        pageNumber: pageNumber ?? this.pageNumber,
      );
}

/// How far the listing has got. The query travels with every state, so the
/// filters survive a failure and a retry.
sealed class SystemAdminListState
    implements ListState<SystemAdminQuery, PersonSummary> {
  const SystemAdminListState(this.query);

  @override
  final SystemAdminQuery query;
}

final class SystemAdminListLoading extends SystemAdminListState
    implements ListLoading<SystemAdminQuery, PersonSummary> {
  const SystemAdminListLoading(super.query);
}

/// A page arrived. [busy] keeps the rows on screen while a further page or
/// search is in flight.
final class SystemAdminListLoaded extends SystemAdminListState
    implements ListLoaded<SystemAdminQuery, PersonSummary> {
  const SystemAdminListLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<PersonSummary> page;

  @override
  final bool busy;
}

/// AF-38c/d — the request failed, and the query that failed is kept.
final class SystemAdminListFailed extends SystemAdminListState
    implements ListFailed<SystemAdminQuery, PersonSummary> {
  const SystemAdminListFailed(super.query, this.failure);

  @override
  final Failure failure;
}

/// Disposed when the screen is left, so a return starts from a fresh,
/// unfiltered list rather than a stale one.
final NotifierProvider<SystemAdminListController, SystemAdminListState>
systemAdminListControllerProvider =
    NotifierProvider.autoDispose<
      SystemAdminListController,
      SystemAdminListState
    >(SystemAdminListController.new);

/// Owns the System Admins listing: its filters, its page, and the request in
/// flight.
class SystemAdminListController
    extends
        PagedListController<
          SystemAdminQuery,
          PersonSummary,
          SystemAdminListState
        > {
  /// A new search starts at the first page.
  Future<void> search({String? name, String? email}) =>
      request(latest.copyWith(name: name, email: email, pageNumber: 1));

  Future<void> clearFilters() => request(const SystemAdminQuery());

  @override
  SystemAdminQuery get initialQuery => const SystemAdminQuery();

  @override
  int pageNumberOf(SystemAdminQuery query) => query.pageNumber;

  @override
  SystemAdminQuery withPageNumber(SystemAdminQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<PersonSummary>>> fetch(SystemAdminQuery query) => ref
      .read(personRepositoryProvider)
      .listSystemAdmins(
        name: query.name,
        email: query.email,
        pageNumber: query.pageNumber,
      );

  @override
  SystemAdminListState loadingState(SystemAdminQuery query) =>
      SystemAdminListLoading(query);

  @override
  SystemAdminListState loadedState(
    SystemAdminQuery query,
    Page<PersonSummary> page, {
    bool busy = false,
  }) => SystemAdminListLoaded(query, page, busy: busy);

  @override
  SystemAdminListState failedState(SystemAdminQuery query, Failure failure) =>
      SystemAdminListFailed(query, failure);
}
