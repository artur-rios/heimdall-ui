import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
import '../domain/scope_permission.dart';
import '../domain/scope_permission_repository.dart';

/// What the listing is currently asking the API for.
class PermissionQuery {
  const PermissionQuery({
    this.name = '',
    this.includeDeleted = false,
    this.pageNumber = 1,
  });

  final String name;
  final bool includeDeleted;
  final int pageNumber;

  /// Whether the user has narrowed the listing at all, which is what tells an
  /// empty result from an unfiltered empty collection (AF-24a).
  bool get isFiltered => name.trim().isNotEmpty || includeDeleted;

  PermissionQuery copyWith({
    String? name,
    bool? includeDeleted,
    int? pageNumber,
  }) => PermissionQuery(
    name: name ?? this.name,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    pageNumber: pageNumber ?? this.pageNumber,
  );
}

/// How far the listing has got. The query travels with every state, so the
/// filters survive a failure and a retry.
sealed class PermissionListState
    implements ListState<PermissionQuery, ScopePermission> {
  const PermissionListState(this.query);

  @override
  final PermissionQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class PermissionListLoading extends PermissionListState
    implements ListLoading<PermissionQuery, ScopePermission> {
  const PermissionListLoading(super.query);
}

/// A page arrived.
final class PermissionListLoaded extends PermissionListState
    implements ListLoaded<PermissionQuery, ScopePermission> {
  const PermissionListLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<ScopePermission> page;

  @override
  final bool busy;
}

/// AF-24b and AF-24c — the request failed, and the query that failed is kept.
final class PermissionListFailed extends PermissionListState
    implements ListFailed<PermissionQuery, ScopePermission> {
  const PermissionListFailed(super.query, this.failure);

  @override
  final Failure failure;

  /// AF-24c — a scope this admin does not own.
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

final NotifierProviderFamily<
  PermissionListController,
  PermissionListState,
  String
>
permissionListControllerProvider =
    NotifierProvider.family<
      PermissionListController,
      PermissionListState,
      String
    >(PermissionListController.new);

/// Owns one scope's permission listing.
class PermissionListController
    extends
        PagedListController<
          PermissionQuery,
          ScopePermission,
          PermissionListState
        > {
  PermissionListController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  /// A new search starts at the first page.
  Future<void> search(String name) =>
      request(latest.copyWith(name: name, pageNumber: 1));

  Future<void> setIncludeDeleted(bool includeDeleted) =>
      request(latest.copyWith(includeDeleted: includeDeleted, pageNumber: 1));

  /// AF-24a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => request(const PermissionQuery());

  @override
  PermissionQuery get initialQuery => const PermissionQuery();

  @override
  int pageNumberOf(PermissionQuery query) => query.pageNumber;

  @override
  PermissionQuery withPageNumber(PermissionQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<ScopePermission>>> fetch(PermissionQuery query) => ref
      .read(scopePermissionRepositoryProvider)
      .list(
        scopeId: arg,
        name: query.name,
        includeDeleted: query.includeDeleted,
        pageNumber: query.pageNumber,
      );

  @override
  PermissionListState loadingState(PermissionQuery query) =>
      PermissionListLoading(query);

  @override
  PermissionListState loadedState(
    PermissionQuery query,
    Page<ScopePermission> page, {
    bool busy = false,
  }) => PermissionListLoaded(query, page, busy: busy);

  @override
  PermissionListState failedState(PermissionQuery query, Failure failure) =>
      PermissionListFailed(query, failure);
}
