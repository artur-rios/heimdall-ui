import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
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
sealed class GoogleUserListState {
  const GoogleUserListState(this.query);

  final GoogleUserQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class GoogleUserListLoading extends GoogleUserListState {
  const GoogleUserListLoading(super.query);
}

/// A page arrived.
final class GoogleUserListLoaded extends GoogleUserListState {
  const GoogleUserListLoaded(super.query, this.page, {this.busy = false});

  final Page<GoogleUser> page;
  final bool busy;
}

/// AF-28b and AF-28c — the request failed, and the query that failed is kept.
final class GoogleUserListFailed extends GoogleUserListState {
  const GoogleUserListFailed(super.query, this.failure);

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
    extends FamilyNotifier<GoogleUserListState, String> {
  bool _inFlight = false;

  @override
  GoogleUserListState build(String scopeId) =>
      const GoogleUserListLoading(GoogleUserQuery());

  Future<void> load() => _fetch(state.query);

  /// A new search starts at the first page.
  Future<void> search({String? name, String? email}) =>
      _fetch(state.query.copyWith(name: name, email: email, pageNumber: 1));

  Future<void> setIncludeDeleted(bool includeDeleted) => _fetch(
    state.query.copyWith(includeDeleted: includeDeleted, pageNumber: 1),
  );

  Future<void> goToPage(int pageNumber) =>
      _fetch(state.query.copyWith(pageNumber: pageNumber));

  /// AF-28a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => _fetch(const GoogleUserQuery());

  Future<void> _fetch(GoogleUserQuery query) async {
    if (_inFlight) {
      return;
    }

    final current = state;
    _inFlight = true;

    state = current is GoogleUserListLoaded
        ? GoogleUserListLoaded(query, current.page, busy: true)
        : GoogleUserListLoading(query);

    try {
      final result = await ref
          .read(googleUserRepositoryProvider)
          .list(
            scopeId: arg,
            name: query.name,
            email: query.email,
            includeDeleted: query.includeDeleted,
            pageNumber: query.pageNumber,
          );

      state = result.fold(
        onSuccess: (page) => GoogleUserListLoaded(query, page),
        onFailure: (failure) => GoogleUserListFailed(query, failure),
      );
    } finally {
      _inFlight = false;
    }
  }
}
