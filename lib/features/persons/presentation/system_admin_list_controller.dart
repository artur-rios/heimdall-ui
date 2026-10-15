import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
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
sealed class SystemAdminListState {
  const SystemAdminListState(this.query);

  final SystemAdminQuery query;
}

final class SystemAdminListLoading extends SystemAdminListState {
  const SystemAdminListLoading(super.query);
}

/// A page arrived. [busy] keeps the rows on screen while a further page or
/// search is in flight.
final class SystemAdminListLoaded extends SystemAdminListState {
  const SystemAdminListLoaded(super.query, this.page, {this.busy = false});

  final Page<PersonSummary> page;
  final bool busy;
}

/// AF-38c/d — the request failed, and the query that failed is kept.
final class SystemAdminListFailed extends SystemAdminListState {
  const SystemAdminListFailed(super.query, this.failure);

  final Failure failure;

  /// AF-38c — only a System Admin may list System Admins.
  bool get isForbidden => failure.kind == FailureKind.forbidden;
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
class SystemAdminListController extends Notifier<SystemAdminListState> {
  bool _inFlight = false;

  /// The newest query asked for while another was in flight, asked as soon as
  /// that one is answered.
  SystemAdminQuery? _queued;

  /// What the next change builds on: the queued query when there is one, so
  /// two changes during one load both survive.
  SystemAdminQuery get _latest => _queued ?? state.query;

  @override
  SystemAdminListState build() =>
      const SystemAdminListLoading(SystemAdminQuery());

  Future<void> load() => _fetch(_latest);

  /// A new search starts at the first page.
  Future<void> search({String? name, String? email}) =>
      _fetch(_latest.copyWith(name: name, email: email, pageNumber: 1));

  Future<void> goToPage(int pageNumber) =>
      _fetch(_latest.copyWith(pageNumber: pageNumber));

  Future<void> clearFilters() => _fetch(const SystemAdminQuery());

  Future<void> _fetch(SystemAdminQuery query) async {
    if (_inFlight) {
      _queued = query;

      return;
    }

    final current = state;
    _inFlight = true;

    state = current is SystemAdminListLoaded
        ? SystemAdminListLoaded(query, current.page, busy: true)
        : SystemAdminListLoading(query);

    final Result<Page<PersonSummary>> result;

    try {
      result = await ref
          .read(personRepositoryProvider)
          .listSystemAdmins(
            name: query.name,
            email: query.email,
            pageNumber: query.pageNumber,
          );
    } finally {
      _inFlight = false;
    }

    if (!ref.mounted) {
      return;
    }

    state = result.fold(
      onSuccess: (page) => SystemAdminListLoaded(query, page),
      onFailure: (failure) => SystemAdminListFailed(query, failure),
    );

    if (_queued case final queued?) {
      _queued = null;
      await _fetch(queued);
    }
  }
}
