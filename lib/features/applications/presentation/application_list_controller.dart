import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
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
sealed class ApplicationListState {
  const ApplicationListState(this.query);

  final ApplicationQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class ApplicationListLoading extends ApplicationListState {
  const ApplicationListLoading(super.query);
}

/// A page arrived, with its owners resolved as far as they could be.
final class ApplicationListLoaded extends ApplicationListState {
  const ApplicationListLoaded(
    super.query,
    this.page, {
    required this.ownerLabel,
    this.busy = false,
  });

  final Page<Application> page;
  final bool busy;

  /// FR-AP-08 and AF-20d — the owner's name, or their identifier when the API
  /// would not resolve it.
  final String Function(String ownerId) ownerLabel;
}

/// AF-20b and AF-20c — the request failed, and the query that failed is kept.
final class ApplicationListFailed extends ApplicationListState {
  const ApplicationListFailed(super.query, this.failure);

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
    extends FamilyNotifier<ApplicationListState, String> {
  bool _inFlight = false;
  late final OwnerNames _owners = OwnerNames(
    ref.read(personRepositoryProvider),
  );

  @override
  ApplicationListState build(String scopeId) =>
      const ApplicationListLoading(ApplicationQuery());

  Future<void> load() => _fetch(state.query);

  /// A new search starts at the first page.
  Future<void> search(String name) =>
      _fetch(state.query.copyWith(name: name, pageNumber: 1));

  Future<void> setIncludeDeleted(bool includeDeleted) => _fetch(
    state.query.copyWith(includeDeleted: includeDeleted, pageNumber: 1),
  );

  Future<void> goToPage(int pageNumber) =>
      _fetch(state.query.copyWith(pageNumber: pageNumber));

  /// AF-20a — returns to the unfiltered listing from the empty-result panel.
  Future<void> clearFilters() => _fetch(const ApplicationQuery());

  Future<void> _fetch(ApplicationQuery query) async {
    if (_inFlight) {
      return;
    }

    final current = state;
    _inFlight = true;

    state = current is ApplicationListLoaded
        ? ApplicationListLoaded(
            query,
            current.page,
            ownerLabel: current.ownerLabel,
            busy: true,
          )
        : ApplicationListLoading(query);

    try {
      final result = await ref
          .read(applicationRepositoryProvider)
          .list(
            scopeId: arg,
            name: query.name,
            includeDeleted: query.includeDeleted,
            pageNumber: query.pageNumber,
          );

      switch (result) {
        case Success<Page<Application>>(:final value):
          // The owners are resolved before the page is shown, so a row never
          // flickers from an identifier to a name under the reader's eye.
          await _owners.resolve(
            value.items.map((application) => application.ownerId),
          );
          state = ApplicationListLoaded(
            query,
            value,
            ownerLabel: _owners.labelFor,
          );
        case FailureResult<Page<Application>>(:final failure):
          state = ApplicationListFailed(query, failure);
      }
    } finally {
      _inFlight = false;
    }
  }
}
