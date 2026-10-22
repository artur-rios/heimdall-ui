import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
import '../domain/google_user.dart';
import '../domain/google_user_repository.dart';

/// What the listing is currently asking the API for.
class GoogleUserQuery {
  const GoogleUserQuery({
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
  /// empty result from a scope nobody has signed into (AF-28a).
  bool get isFiltered =>
      name.trim().isNotEmpty || email.trim().isNotEmpty || includeDeleted;

  GoogleUserQuery copyWith({
    String? name,
    String? email,
    bool? includeDeleted,
    int? pageNumber,
  }) => GoogleUserQuery(
    name: name ?? this.name,
    email: email ?? this.email,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    pageNumber: pageNumber ?? this.pageNumber,
  );
}

/// How far the listing has got.
sealed class GoogleUserListState
    implements ListState<GoogleUserQuery, GoogleUser> {
  const GoogleUserListState(this.query);

  @override
  final GoogleUserQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class GoogleUserListLoading extends GoogleUserListState
    implements ListLoading<GoogleUserQuery, GoogleUser> {
  const GoogleUserListLoading(super.query);
}

/// A page arrived.
final class GoogleUserListLoaded extends GoogleUserListState
    implements ListLoaded<GoogleUserQuery, GoogleUser> {
  const GoogleUserListLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<GoogleUser> page;

  @override
  final bool busy;
}

/// AF-28b and AF-28c — the request failed, and the query that failed is kept.
final class GoogleUserListFailed extends GoogleUserListState
    implements ListFailed<GoogleUserQuery, GoogleUser> {
  const GoogleUserListFailed(super.query, this.failure);

  @override
  final Failure failure;

  /// AF-28c — a scope this admin does not own.
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

final NotifierProviderFamily<
  GoogleUserListController,
  GoogleUserListState,
  String
>
googleUserListControllerProvider =
    NotifierProvider.family<
      GoogleUserListController,
      GoogleUserListState,
      String
    >(GoogleUserListController.new);

/// Owns one scope's Google user listing.
class GoogleUserListController
    extends
        PagedListController<GoogleUserQuery, GoogleUser, GoogleUserListState> {
  GoogleUserListController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  /// A new search starts at the first page.
  Future<void> search({String? name, String? email}) =>
      request(latest.copyWith(name: name, email: email, pageNumber: 1));

  Future<void> setIncludeDeleted(bool includeDeleted) =>
      request(latest.copyWith(includeDeleted: includeDeleted, pageNumber: 1));

  /// AF-28a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => request(const GoogleUserQuery());

  @override
  GoogleUserQuery get initialQuery => const GoogleUserQuery();

  @override
  int pageNumberOf(GoogleUserQuery query) => query.pageNumber;

  @override
  GoogleUserQuery withPageNumber(GoogleUserQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<GoogleUser>>> fetch(GoogleUserQuery query) => ref
      .read(googleUserRepositoryProvider)
      .list(
        scopeId: arg,
        name: query.name,
        email: query.email,
        includeDeleted: query.includeDeleted,
        pageNumber: query.pageNumber,
      );

  @override
  GoogleUserListState loadingState(GoogleUserQuery query) =>
      GoogleUserListLoading(query);

  @override
  GoogleUserListState loadedState(
    GoogleUserQuery query,
    Page<GoogleUser> page, {
    bool busy = false,
  }) => GoogleUserListLoaded(query, page, busy: busy);

  @override
  GoogleUserListState failedState(GoogleUserQuery query, Failure failure) =>
      GoogleUserListFailed(query, failure);
}
