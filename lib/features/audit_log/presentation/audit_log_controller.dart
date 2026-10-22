import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../shared/formatting/identifier.dart';
import '../../../shared/paging/list_state.dart';
import '../../../shared/paging/paged_list_controller.dart';
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
sealed class AuditLogState implements ListState<AuditLogQuery, AuditEntry> {
  const AuditLogState(this.query);

  @override
  final AuditLogQuery query;
}

/// The first page is on its way and the list shows a placeholder.
final class AuditLogLoading extends AuditLogState
    implements ListLoading<AuditLogQuery, AuditEntry> {
  const AuditLogLoading(super.query);
}

/// A page arrived.
final class AuditLogLoaded extends AuditLogState
    implements ListLoaded<AuditLogQuery, AuditEntry> {
  const AuditLogLoaded(super.query, this.page, {this.busy = false});

  @override
  final Page<AuditEntry> page;

  @override
  final bool busy;
}

/// AF-34b, AF-34c, AF-34e — the request failed, and the query that failed is kept.
final class AuditLogFailed extends AuditLogState
    implements ListFailed<AuditLogQuery, AuditEntry> {
  const AuditLogFailed(super.query, this.failure);

  @override
  final Failure failure;
}

final NotifierProvider<AuditLogController, AuditLogState>
auditLogControllerProvider =
    NotifierProvider<AuditLogController, AuditLogState>(AuditLogController.new);

/// Owns the audit-trail listing (UI-34).
class AuditLogController
    extends PagedListController<AuditLogQuery, AuditEntry, AuditLogState> {
  Future<void> setDays(DateTime firstDay, DateTime lastDay) => _filter(
    latest.filter.copyWith(firstDay: () => firstDay, lastDay: () => lastDay),
  );

  Future<void> clearDays() => _filter(
    latest.filter.copyWith(firstDay: () => null, lastDay: () => null),
  );

  /// An empty action is no filter at all, as the API reads it.
  Future<void> setAction(String action) {
    final trimmed = action.trim();

    return _filter(
      latest.filter.copyWith(action: () => trimmed.isEmpty ? null : trimmed),
    );
  }

  /// AF-34d — `false`, and nothing sent, when [text] is not an identifier.
  bool setActor(String text) => _setIdentifier(
    text,
    (value) => latest.filter.copyWith(actorId: () => value),
  );

  /// AF-34d, for the target.
  bool setTarget(String text) => _setIdentifier(
    text,
    (value) => latest.filter.copyWith(targetId: () => value),
  );

  Future<void> setOutcome(bool? succeeded) =>
      _filter(latest.filter.copyWith(succeeded: () => succeeded));

  Future<void> clearFilters() => _filter(const AuditLogFilter());

  bool _setIdentifier(
    String text,
    AuditLogFilter Function(String? value) apply,
  ) {
    if (text.trim().isEmpty) {
      unawaited(_filter(apply(null)));

      return true;
    }

    if (!isIdentifier(text)) {
      return false;
    }

    unawaited(_filter(apply(normaliseIdentifier(text))));

    return true;
  }

  /// A new filter starts at the first page.
  Future<void> _filter(AuditLogFilter filter) =>
      request(latest.copyWith(filter: filter, pageNumber: 1));

  @override
  AuditLogQuery get initialQuery => const AuditLogQuery();

  @override
  int pageNumberOf(AuditLogQuery query) => query.pageNumber;

  @override
  AuditLogQuery withPageNumber(AuditLogQuery query, int pageNumber) =>
      query.copyWith(pageNumber: pageNumber);

  @override
  Future<Result<Page<AuditEntry>>> fetch(AuditLogQuery query) => ref
      .read(auditLogRepositoryProvider)
      .list(filter: query.filter, pageNumber: query.pageNumber);

  @override
  AuditLogState loadingState(AuditLogQuery query) => AuditLogLoading(query);

  @override
  AuditLogState loadedState(
    AuditLogQuery query,
    Page<AuditEntry> page, {
    bool busy = false,
  }) => AuditLogLoaded(query, page, busy: busy);

  @override
  AuditLogState failedState(AuditLogQuery query, Failure failure) =>
      AuditLogFailed(query, failure);
}
