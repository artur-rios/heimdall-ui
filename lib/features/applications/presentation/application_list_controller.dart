import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/application.dart';
import '../domain/application_repository.dart';
import 'owner_names.dart';

/// What the listing is currently asking the API for.
class ApplicationQuery {
  const ApplicationQuery({
    this.name = '',
    this.includeDeleted = false,
    this.pageNumber = 1,
  });

  final String name;
  final bool includeDeleted;
  final int pageNumber;

  /// Whether the user has narrowed the listing at all, which is what tells an
  /// empty result from an unfiltered empty collection (AF-20a).
  bool get isFiltered => name.trim().isNotEmpty || includeDeleted;

  ApplicationQuery copyWith({
    String? name,
    bool? includeDeleted,
    int? pageNumber,
  }) => ApplicationQuery(
    name: name ?? this.name,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    pageNumber: pageNumber ?? this.pageNumber,
  );
}

/// How far the listing has got. The query travels with every state, so the
/// filters survive a failure and a retry.
sealed class ApplicationListState
    implements ListState<ApplicationQuery, Application> {
  const ApplicationListState(this.query);

  @override
  final ApplicationQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class ApplicationListLoading extends ApplicationListState
    implements ListLoading<ApplicationQuery, Application> {
  const ApplicationListLoading(super.query);
}

/// A page arrived, with its owners resolved as far as they could be.
final class ApplicationListLoaded extends ApplicationListState
    implements ListLoaded<ApplicationQuery, Application> {
  const ApplicationListLoaded(
    super.query,
    this.page, {
    required this.ownerLabel,
    this.busy = false,
  });

  @override
  final Page<Application> page;

  @override
  final bool busy;

  /// FR-AP-08 and AF-20d — the owner's name, or their identifier when the API
  /// would not resolve it.
  final String Function(String ownerId) ownerLabel;
}

/// AF-20b and AF-20c — the request failed, and the query that failed is kept.
final class ApplicationListFailed extends ApplicationListState
    implements ListFailed<ApplicationQuery, Application> {
  const ApplicationListFailed(super.query, this.failure);

  @override
  final Failure failure;

  /// AF-20c — a scope this admin does not own.
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

final NotifierProviderFamily<
  ApplicationListController,
  ApplicationListState,
  String
>
applicationListControllerProvider =
    NotifierProvider.family<
      ApplicationListController,
      ApplicationListState,
      String
    >(ApplicationListController.new);

/// Owns one scope's application listing.
class ApplicationListController
    extends
        PagedListController<
          ApplicationQuery,
          Application,
          ApplicationListState
        > {
  ApplicationListController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  /// The owners' names learned under this build. A reset starts afresh, and a
  /// request of an earlier build keeps teaching only the names it began with.
  OwnerNames? _ownersOfBuild;

  OwnerNames get _owners =>
      _ownersOfBuild ??= OwnerNames(ref.read(personRepositoryProvider));

  @override
  ApplicationListState build() {
    _ownersOfBuild = null;

    return super.build();
  }

  /// Reads the page the current query names, with the owners' names read
  /// afresh: a reload is where a renamed owner should show their new name.
  /// Moving between pages and filters keeps what was learned.
  @override
  Future<void> load() {
    _owners.forget();

    return super.load();
  }

  /// A new search starts at the first page.
  Future<void> search(String name) =>
      request(latest.copyWith(name: name, pageNumber: 1));

  Future<void> setIncludeDeleted(bool includeDeleted) =>
      request(latest.copyWith(includeDeleted: includeDeleted, pageNumber: 1));

  /// AF-20a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => request(const ApplicationQuery());

  @override
  ApplicationQuery get initialQuery => const ApplicationQuery();

  @override
  int pageNumberOf(ApplicationQuery query) => query.pageNumber;

  @override
  ApplicationQuery withPageNumber(ApplicationQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  /// The owners are resolved here, inside the engine's guard too: a read of
  /// theirs that throws must end in the failed state, not strand the list.
  @override
  Future<Result<Page<Application>>> fetch(ApplicationQuery query) async {
    final owners = _owners;
    final listed = await ref
        .read(applicationRepositoryProvider)
        .list(
          scopeId: arg,
          name: query.name,
          includeDeleted: query.includeDeleted,
          pageNumber: query.pageNumber,
        );

    if (listed case Success<Page<Application>>(:final value)) {
      // The owners are resolved before the page is shown, so a row never
      // flickers from an identifier to a name under the reader's eye.
      await owners.resolve(
        value.items.map((application) => application.ownerId),
      );
    }

    return listed;
  }

  @override
  ApplicationListState loadingState(ApplicationQuery query) =>
      ApplicationListLoading(query);

  @override
  ApplicationListState loadedState(
    ApplicationQuery query,
    Page<Application> page, {
    bool busy = false,
  }) => ApplicationListLoaded(
    query,
    page,
    ownerLabel: _owners.labelFor,
    busy: busy,
  );

  @override
  ApplicationListState failedState(ApplicationQuery query, Failure failure) =>
      ApplicationListFailed(query, failure);
}
