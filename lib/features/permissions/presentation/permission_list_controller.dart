import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
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
sealed class PermissionListState {
  const PermissionListState(this.query);

  final PermissionQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class PermissionListLoading extends PermissionListState {
  const PermissionListLoading(super.query);
}

/// A page arrived.
final class PermissionListLoaded extends PermissionListState {
  const PermissionListLoaded(super.query, this.page, {this.busy = false});

  final Page<ScopePermission> page;
  final bool busy;
}

/// AF-24b and AF-24c — the request failed, and the query that failed is kept.
final class PermissionListFailed extends PermissionListState {
  const PermissionListFailed(super.query, this.failure);

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
    extends FamilyNotifier<PermissionListState, String> {
  bool _inFlight = false;

  @override
  PermissionListState build(String scopeId) =>
      const PermissionListLoading(PermissionQuery());

  Future<void> load() => _fetch(state.query);

  /// A new search starts at the first page.
  Future<void> search(String name) =>
      _fetch(state.query.copyWith(name: name, pageNumber: 1));

  Future<void> setIncludeDeleted(bool includeDeleted) => _fetch(
    state.query.copyWith(includeDeleted: includeDeleted, pageNumber: 1),
  );

  Future<void> goToPage(int pageNumber) =>
      _fetch(state.query.copyWith(pageNumber: pageNumber));

  /// AF-24a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => _fetch(const PermissionQuery());

  Future<void> _fetch(PermissionQuery query) async {
    if (_inFlight) {
      return;
    }

    final current = state;
    _inFlight = true;

    state = current is PermissionListLoaded
        ? PermissionListLoaded(query, current.page, busy: true)
        : PermissionListLoading(query);

    try {
      final result = await ref
          .read(scopePermissionRepositoryProvider)
          .list(
            scopeId: arg,
            name: query.name,
            includeDeleted: query.includeDeleted,
            pageNumber: query.pageNumber,
          );

      state = result.fold(
        onSuccess: (page) => PermissionListLoaded(query, page),
        onFailure: (failure) => PermissionListFailed(query, failure),
      );
    } finally {
      _inFlight = false;
    }
  }
}
