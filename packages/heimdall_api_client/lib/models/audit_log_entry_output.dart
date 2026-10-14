// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'audit_log_entry_output.g.dart';

@JsonSerializable()
class AuditLogEntryOutput {
  const AuditLogEntryOutput({
    this.id,
    this.recordedAt,
    this.actorId,
    this.actorRole,
    this.action,
    this.targetId,
    this.succeeded,
    this.failureReason,
  });

  factory AuditLogEntryOutput.fromJson(Map<String, Object?> json) =>
      _$AuditLogEntryOutputFromJson(json);

  final String? id;
  final DateTime? recordedAt;
  final String? actorId;
  final int? actorRole;
  final String? action;
  final String? targetId;
  final bool? succeeded;
  final String? failureReason;

  Map<String, Object?> toJson() => _$AuditLogEntryOutputToJson(this);
}
