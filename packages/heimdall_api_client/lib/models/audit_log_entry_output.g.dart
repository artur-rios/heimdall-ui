// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_entry_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditLogEntryOutput _$AuditLogEntryOutputFromJson(Map<String, dynamic> json) =>
    AuditLogEntryOutput(
      id: json['id'] as String?,
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.parse(json['recordedAt'] as String),
      actorId: json['actorId'] as String?,
      actorRole: (json['actorRole'] as num?)?.toInt(),
      action: json['action'] as String?,
      targetId: json['targetId'] as String?,
      succeeded: json['succeeded'] as bool?,
      failureReason: json['failureReason'] as String?,
    );

Map<String, dynamic> _$AuditLogEntryOutputToJson(
  AuditLogEntryOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'recordedAt': instance.recordedAt?.toIso8601String(),
  'actorId': instance.actorId,
  'actorRole': instance.actorRole,
  'action': instance.action,
  'targetId': instance.targetId,
  'succeeded': instance.succeeded,
  'failureReason': instance.failureReason,
};
