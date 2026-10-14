import '../../auth/domain/session.dart';

/// One entry of the audit trail as the API stores it (UC-48). Nothing here is
/// looked up or reconstructed: an anonymous action has no actor, a cleared
/// attribution stays `null`, and a target is an identifier whose kind the
/// trail does not record.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.succeeded,
    this.recordedAt,
    this.actorId,
    this.actorRole,
    this.targetId,
    this.failureReason,
  });

  final String id;
  final DateTime? recordedAt;

  /// `null` when the entry had no actor or its attribution was cleared.
  final String? actorId;
  final Role? actorRole;

  /// The command's type name, e.g. `CreateScopeCommand`.
  final String action;
  final String? targetId;
  final bool succeeded;

  /// Why a refused action was refused, in the API's canonical words.
  final String? failureReason;
}

/// What the audit listing is narrowed to. Every field is optional and they
/// combine; the day fields are the local days the administrator picked.
class AuditLogFilter {
  const AuditLogFilter({
    this.firstDay,
    this.lastDay,
    this.action,
    this.actorId,
    this.targetId,
    this.succeeded,
  });

  final DateTime? firstDay;
  final DateTime? lastDay;
  final String? action;
  final String? actorId;
  final String? targetId;

  /// `true` for completed actions, `false` for refusals, `null` for both.
  final bool? succeeded;

  bool get isFiltered =>
      firstDay != null ||
      lastDay != null ||
      action != null ||
      actorId != null ||
      targetId != null ||
      succeeded != null;

  /// Each argument is a function so a field can be set back to `null`.
  AuditLogFilter copyWith({
    DateTime? Function()? firstDay,
    DateTime? Function()? lastDay,
    String? Function()? action,
    String? Function()? actorId,
    String? Function()? targetId,
    bool? Function()? succeeded,
  }) => AuditLogFilter(
    firstDay: firstDay == null ? this.firstDay : firstDay(),
    lastDay: lastDay == null ? this.lastDay : lastDay(),
    action: action == null ? this.action : action(),
    actorId: actorId == null ? this.actorId : actorId(),
    targetId: targetId == null ? this.targetId : targetId(),
    succeeded: succeeded == null ? this.succeeded : succeeded(),
  );
}

/// The API's inclusive `from`/`to` for the local days [firstDay] to [lastDay]:
/// the start of the first and the last millisecond of the last, in UTC. The
/// API reads its bounds as UTC, so a day picked west of UTC must be converted
/// here or the evening's entries would fall outside it.
({DateTime from, DateTime to}) auditBoundsFor(
  DateTime firstDay,
  DateTime lastDay,
) => (
  from: DateTime(firstDay.year, firstDay.month, firstDay.day).toUtc(),
  to: DateTime(
    lastDay.year,
    lastDay.month,
    lastDay.day,
    23,
    59,
    59,
    999,
  ).toUtc(),
);
