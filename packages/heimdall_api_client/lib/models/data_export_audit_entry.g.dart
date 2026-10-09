// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_audit_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportAuditEntry _$DataExportAuditEntryFromJson(
  Map<String, dynamic> json,
) => DataExportAuditEntry(
  id: json['id'] as String?,
  action: json['action'] as String?,
  targetId: json['targetId'] as String?,
  succeeded: json['succeeded'] as bool?,
  failureReason: json['failureReason'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$DataExportAuditEntryToJson(
  DataExportAuditEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'action': instance.action,
  'targetId': instance.targetId,
  'succeeded': instance.succeeded,
  'failureReason': instance.failureReason,
  'createdAt': instance.createdAt?.toIso8601String(),
};
