// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_entry_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditLogEntryOutput _$AuditLogEntryOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'recordedAt',
      'actorId',
      'actorRole',
      'action',
      'targetId',
      'succeeded',
      'failureReason',
    ],
    disallowNullValues: const ['id', 'recordedAt', 'succeeded'],
  );
  return AuditLogEntryOutput(
    id: json['id'] as String?,
    recordedAt: AuditLogEntryOutput._read_recordedAt(json['recordedAt']),
    actorId: json['actorId'] as String?,
    actorRole: AuditLogEntryOutput._read_actorRole(json['actorRole']),
    action: json['action'] as String?,
    targetId: json['targetId'] as String?,
    succeeded: json['succeeded'] as bool?,
    failureReason: json['failureReason'] as String?,
  );
}

Map<String, dynamic> _$AuditLogEntryOutputToJson(
  AuditLogEntryOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'recordedAt': ?AuditLogEntryOutput._write_recordedAt(instance.recordedAt),
  'actorId': ?instance.actorId,
  'actorRole': ?AuditLogEntryOutput._write_actorRole(instance.actorRole),
  'action': ?instance.action,
  'targetId': ?instance.targetId,
  'succeeded': ?instance.succeeded,
  'failureReason': ?instance.failureReason,
};
