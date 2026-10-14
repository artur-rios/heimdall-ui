import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/pending_registration.dart';
import '../domain/pending_registration_repository.dart';

sealed class PendingRegistrationListState {
  const PendingRegistrationListState(this.pageNumber);

  final int pageNumber;
}

final class PendingRegistrationListLoading
    extends PendingRegistrationListState {
  const PendingRegistrationListLoading(super.pageNumber);
}

final class PendingRegistrationListLoaded extends PendingRegistrationListState {
  const PendingRegistrationListLoaded(
    super.pageNumber,
    this.page, {
    this.busy = false,
    this.notice,
    this.discardFailure,
  });

  final Page<PendingRegistration> page;
  final bool busy;

  /// "Registration discarded." or AF-35d's "That registration no longer exists."
  final String? notice;

  /// AF-35b/AF-35f on a discard — the list itself is kept.
  final Failure? discardFailure;
}

/// AF-35b, AF-35c, AF-35f on the list.
final class PendingRegistrationListFailed extends PendingRegistrationListState {
  const PendingRegistrationListFailed(super.pageNumber, this.failure);

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
    extends Notifier<PendingRegistrationListState> {
  PendingRegistrationListController(this.arg);

  final String arg;
  bool _inFlight = false;
  int? _queued;

  PendingRegistrationRepository get _repository =>
      ref.read(pendingRegistrationRepositoryProvider);

  @override
  PendingRegistrationListState build() =>
      const PendingRegistrationListLoading(1);

  Future<void> load() => _fetch(state.pageNumber);

  Future<void> goToPage(int pageNumber) => _fetch(pageNumber);

  Future<void> discard(PendingRegistration registration) async {
    final result = await _repository.discard(arg, registration.id);
    final failure = result.failureOrNull;

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

    await _fetch(state.pageNumber);

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

  Future<void> _fetch(int pageNumber) async {
    if (_inFlight) {
      _queued = pageNumber;

      return;
    }

    final current = state;
    _inFlight = true;

    state = current is PendingRegistrationListLoaded
        ? PendingRegistrationListLoaded(pageNumber, current.page, busy: true)
        : PendingRegistrationListLoading(pageNumber);

    try {
      final result = await _repository.list(arg, pageNumber: pageNumber);

      state = result.fold(
        onSuccess: (page) => PendingRegistrationListLoaded(pageNumber, page),
        onFailure: (failure) =>
            PendingRegistrationListFailed(pageNumber, failure),
      );
    } finally {
      _inFlight = false;
    }

    if (_queued case final queued?) {
      _queued = null;
      await _fetch(queued);

      return;
    }

    // Discarding the last row of the last page leaves an empty page past the end.
    if (state case PendingRegistrationListLoaded(:final page)
        when page.items.isEmpty && pageNumber > 1) {
      await _fetch(page.totalPages.clamp(1, pageNumber - 1));
    }
  }
}
