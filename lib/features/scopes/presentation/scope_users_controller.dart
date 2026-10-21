import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
import '../../persons/domain/person.dart';
import '../../profile/presentation/profile_controller.dart';

/// What the promotion list is asking the API for.
class ScopeUsersQuery {
  const ScopeUsersQuery({this.search = '', this.pageNumber = 1});

  /// What was typed in the one search box. A value containing an `@` is an
  /// address and anything else is a name, as in the owner picker.
  final String search;
  final int pageNumber;

  /// Whether the list has been narrowed, which tells "nobody matches" from
  /// "the scope has no users".
  bool get isFiltered => search.trim().isNotEmpty;

  ScopeUsersQuery copyWith({String? search, int? pageNumber}) =>
      ScopeUsersQuery(
        search: search ?? this.search,
        pageNumber: pageNumber ?? this.pageNumber,
      );
}

/// How far the promotion list has got.
sealed class ScopeUsersState implements ListState<ScopeUsersQuery, Person> {
  const ScopeUsersState(this.query);

  @override
  final ScopeUsersQuery query;
}

/// The first page is on its way.
final class ScopeUsersLoading extends ScopeUsersState
    implements ListLoading<ScopeUsersQuery, Person> {
  const ScopeUsersLoading(super.query);
}

/// A page of the scope's users is on screen.
final class ScopeUsersLoaded extends ScopeUsersState
    implements ListLoaded<ScopeUsersQuery, Person> {
  const ScopeUsersLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<Person> page;

  @override
  final bool busy;
}

/// The request failed, and the query that failed is kept.
final class ScopeUsersFailed extends ScopeUsersState
    implements ListFailed<ScopeUsersQuery, Person> {
  const ScopeUsersFailed(super.query, this.failure);

  @override
  final Failure failure;
}

final NotifierProviderFamily<ScopeUsersController, ScopeUsersState, String>
scopeUsersControllerProvider =
    NotifierProvider.family<ScopeUsersController, ScopeUsersState, String>(
      ScopeUsersController.new,
    );

/// Owns the users of one scope the owners screen offers for promotion (UI-14).
///
/// A listing of its own, searched and paged by the API, because a scope can
/// have more users than one page and the user who is not on the first page
/// would otherwise never be promotable (#159). Who already owns the scope is
/// left to the screen, which knows the owners.
class ScopeUsersController
    extends PagedListController<ScopeUsersQuery, Person, ScopeUsersState> {
  ScopeUsersController(this.arg);

  /// The family argument this controller was created for: the scope.
  final String arg;

  /// A new search starts at the first page.
  Future<void> search(String text) =>
      request(latest.copyWith(search: text.trim(), pageNumber: 1));

  @override
  ScopeUsersQuery get initialQuery => const ScopeUsersQuery();

  @override
  int pageNumberOf(ScopeUsersQuery query) => query.pageNumber;

  @override
  ScopeUsersQuery withPageNumber(ScopeUsersQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<Person>>> fetch(ScopeUsersQuery query) {
    final search = query.search;
    final isEmail = search.contains('@');

    return ref
        .read(personRepositoryProvider)
        .listScopePersons(
          scopeId: arg,
          name: isEmail || search.isEmpty ? null : search,
          email: isEmail ? search : null,
          pageNumber: query.pageNumber,
        );
  }

  @override
  ScopeUsersState loadingState(ScopeUsersQuery query) =>
      ScopeUsersLoading(query);

  @override
  ScopeUsersState loadedState(
    ScopeUsersQuery query,
    Page<Person> page, {
    bool busy = false,
  }) => ScopeUsersLoaded(query, page, busy: busy);

  @override
  ScopeUsersState failedState(ScopeUsersQuery query, Failure failure) =>
      ScopeUsersFailed(query, failure);
}
