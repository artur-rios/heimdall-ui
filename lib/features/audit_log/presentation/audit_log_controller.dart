import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/formatting/identifier.dart';
import '../domain/audit_entry.dart';
import '../domain/audit_log_repository.dart';

/// What the listing is currently asking the API for.
class AuditLogQuery {
  const AuditLogQuery({
    this.filter = const AuditLogFilter(),
    this.pageNumber = 1,
  });

  final AuditLogFilter filter;
  final int pageNumber;

  AuditLogQuery copyWith({AuditLogFilter? filter, int? pageNumber}) =>
      AuditLogQuery(
        filter: filter ?? this.filter,
        pageNumber: pageNumber ?? this.pageNumber,
      );
}

/// How far the listing has got.
sealed class AuditLogState {
  const AuditLogState(this.query);

  final AuditLogQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class AuditLogLoading extends AuditLogState {
  const AuditLogLoading(super.query);
}

/// A page arrived.
final class AuditLogLoaded extends AuditLogState {
  const AuditLogLoaded(super.query, this.page, {this.busy = false});

  final Page<AuditEntry> page;
  final bool busy;
}

/// AF-34b, AF-34c, AF-34e — the request failed, and the query that failed is kept.
final class AuditLogFailed extends AuditLogState {
  const AuditLogFailed(super.query, this.failure);

  final Failure failure;
}

final NotifierProvider<AuditLogController, AuditLogState>
auditLogControllerProvider =
    NotifierProvider<AuditLogController, AuditLogState>(AuditLogController.new);

/// Owns the audit-trail listing (UI-34).
class AuditLogController extends Notifier<AuditLogState> {
  bool _inFlight = false;

  /// The newest query asked for while another was in flight. It is asked as
  /// soon as that one is answered, so a change made during a load is not lost.
  AuditLogQuery? _queued;

  @override
  AuditLogState build() => const AuditLogLoading(AuditLogQuery());

  Future<void> load() => _fetch(state.query);

  Future<void> goToPage(int pageNumber) =>
      _fetch(state.query.copyWith(pageNumber: pageNumber));

  Future<void> setDays(DateTime firstDay, DateTime lastDay) => _filter(
    state.query.filter.copyWith(
      firstDay: () => firstDay,
      lastDay: () => lastDay,
    ),
  );

  Future<void> clearDays() => _filter(
    state.query.filter.copyWith(firstDay: () => null, lastDay: () => null),
  );

  /// An empty action is no filter at all, as the API reads it.
  Future<void> setAction(String action) {
    final trimmed = action.trim();

    return _filter(
      state.query.filter.copyWith(
        action: () => trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  /// AF-34d — `false`, and nothing sent, when [text] is not an identifier.
  bool setActor(String text) => _setIdentifier(
    text,
    (value) => state.query.filter.copyWith(actorId: () => value),
  );

  /// AF-34d, for the target.
  bool setTarget(String text) => _setIdentifier(
    text,
    (value) => state.query.filter.copyWith(targetId: () => value),
  );

  Future<void> setOutcome(bool? succeeded) =>
      _filter(state.query.filter.copyWith(succeeded: () => succeeded));

  Future<void> clearFilters() => _filter(const AuditLogFilter());

  bool _setIdentifier(
    String text,
    AuditLogFilter Function(String? value) apply,
  ) {
    if (text.trim().isEmpty) {
      _filter(apply(null));

      return true;
    }

    if (!isIdentifier(text)) {
      return false;
    }

    _filter(apply(normaliseIdentifier(text)));

    return true;
  }

  /// A new filter starts at the first page.
  Future<void> _filter(AuditLogFilter filter) =>
      _fetch(state.query.copyWith(filter: filter, pageNumber: 1));

  Future<void> _fetch(AuditLogQuery query) async {
    if (_inFlight) {
      _queued = query;

      return;
    }

    final current = state;
    _inFlight = true;

    state = current is AuditLogLoaded
        ? AuditLogLoaded(query, current.page, busy: true)
        : AuditLogLoading(query);

    try {
      final result = await ref
          .read(auditLogRepositoryProvider)
          .list(filter: query.filter, pageNumber: query.pageNumber);

      state = result.fold(
        onSuccess: (page) => AuditLogLoaded(query, page),
        onFailure: (failure) => AuditLogFailed(query, failure),
      );
    } finally {
      _inFlight = false;
    }

    if (_queued case final queued?) {
      _queued = null;
      await _fetch(queued);

      return;
    }

    // A page past the end — the trail can shrink only through retention, but a
    // narrowed filter can — would show "nothing here" with no pager to go back with.
    if (state case AuditLogLoaded(:final page)
        when page.items.isEmpty && query.pageNumber > 1) {
      await _fetch(
        query.copyWith(
          pageNumber: page.totalPages.clamp(1, query.pageNumber - 1),
        ),
      );
    }
  }
}
