import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
import '../domain/pending_registration.dart';
import '../domain/pending_registration_repository.dart';

/// How far the listing has got. It has no filters, so its query is the page
/// number alone.
sealed class PendingRegistrationListState
    implements ListState<int, PendingRegistration> {
  const PendingRegistrationListState(this.pageNumber);

  final int pageNumber;

  @override
  int get query => pageNumber;
}

final class PendingRegistrationListLoading extends PendingRegistrationListState
    implements ListLoading<int, PendingRegistration> {
  const PendingRegistrationListLoading(super.pageNumber);
}

final class PendingRegistrationListLoaded extends PendingRegistrationListState
    implements ListLoaded<int, PendingRegistration> {
  const PendingRegistrationListLoaded(
    super.pageNumber,
    this.page, {
    this.busy = false,
    this.notice,
    this.discardFailure,
  });

  @override
  final Page<PendingRegistration> page;

  @override
  final bool busy;

  /// "Registration discarded." or AF-35d's "That registration no longer exists."
  final String? notice;

  /// AF-35b/AF-35f on a discard — the list itself is kept.
  final Failure? discardFailure;
}

/// AF-35b, AF-35c, AF-35f on the list.
final class PendingRegistrationListFailed extends PendingRegistrationListState
    implements ListFailed<int, PendingRegistration> {
  const PendingRegistrationListFailed(super.pageNumber, this.failure);

  @override
  final Failure failure;
}

final pendingRegistrationListControllerProvider =
    NotifierProvider.family<
      PendingRegistrationListController,
      PendingRegistrationListState,
      String
    >(PendingRegistrationListController.new);

/// Owns a scope's pending-registration listing (UI-35). The family argument is
/// the scope id.
class PendingRegistrationListController
    extends
        PagedListController<
          int,
          PendingRegistration,
          PendingRegistrationListState
        > {
  PendingRegistrationListController(this.arg);

  final String arg;

  PendingRegistrationRepository get _repository =>
      ref.read(pendingRegistrationRepositoryProvider);

  /// Ignored while the list is busy: the screen loads on every visit, and a
  /// visit during a discard would otherwise drop the discard's busy state and
  /// its notice. Whatever is in flight ends in a fresh list anyway.
  @override
  Future<void> load() async {
    if (_busy) {
      return;
    }

    await super.load();
  }

  /// Ignored while the list is busy, as the pager is then disabled.
  @override
  Future<void> goToPage(int pageNumber) async {
    if (_busy) {
      return;
    }

    await super.goToPage(pageNumber);
  }

  /// Busy from the DELETE until the reload after it ends, so the screen holds
  /// every Discard and the pager meanwhile, and no page fetch can overtake
  /// the reload and drop its notice. A call while busy is ignored: nothing is
  /// sent.
  Future<void> discard(PendingRegistration registration) async {
    if (_busy) {
      return;
    }

    final epoch = this.epoch;

    if (state case final PendingRegistrationListLoaded loaded) {
      state = PendingRegistrationListLoaded(
        loaded.pageNumber,
        loaded.page,
        busy: true,
      );
    }

    final result = await _repository.discard(arg, registration.id);
    final failure = result.failureOrNull;

    if (!isCurrent(epoch)) {
      return;
    }

    if (failure != null && failure.kind != FailureKind.notFound) {
      if (state case final PendingRegistrationListLoaded loaded) {
        state = PendingRegistrationListLoaded(
          loaded.pageNumber,
          loaded.page,
          discardFailure: failure,
        );
      }

      return;
    }

    await request(latest);

    if (!isCurrent(epoch)) {
      return;
    }

    if (state case final PendingRegistrationListLoaded loaded) {
      state = PendingRegistrationListLoaded(
        loaded.pageNumber,
        loaded.page,
        notice: failure == null
            ? 'Registration discarded.'
            : 'That registration no longer exists.',
      );
    }
  }

  bool get _busy => switch (state) {
    PendingRegistrationListLoaded(:final busy) => busy,
    _ => false,
  };

  @override
  int get initialQuery => 1;

  @override
  int pageNumberOf(int query) => query;

  @override
  int withPageNumber(int query, int pageNumber) => pageNumber;

  @override
  Future<Result<Page<PendingRegistration>>> fetch(int query) =>
      _repository.list(arg, pageNumber: query);

  @override
  PendingRegistrationListState loadingState(int query) =>
      PendingRegistrationListLoading(query);

  /// A fresh page drops the notice and the discard failure: they were about
  /// the page before it.
  @override
  PendingRegistrationListState loadedState(
    int query,
    Page<PendingRegistration> page, {
    bool busy = false,
  }) => PendingRegistrationListLoaded(query, page, busy: busy);

  @override
  PendingRegistrationListState failedState(int query, Failure failure) =>
      PendingRegistrationListFailed(query, failure);
}
