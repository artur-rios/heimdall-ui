// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_audit_entry.g.dart';

@JsonSerializable()
class DataExportAuditEntry {
  const DataExportAuditEntry({
    this.id,
    this.action,
    this.targetId,
    this.succeeded,
    this.failureReason,
    this.createdAt,
  });

  factory DataExportAuditEntry.fromJson(Map<String, Object?> json) =>
      _$DataExportAuditEntryFromJson(json);

  final String? id;
  final String? action;
  final String? targetId;
  final bool? succeeded;
  final String? failureReason;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => _$DataExportAuditEntryToJson(this);
}
